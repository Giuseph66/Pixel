// PIXEL signal server. It carries lobby and WebRTC negotiation only; gameplay
// packets never pass through this process.
package main

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"
	"time"
)

const (
	defaultAddress = ":8787"
	maxBodyBytes   = 64 << 10
	roomTTL        = 90 * time.Second
	pollTimeout    = 20 * time.Second
	pollInterval   = 200 * time.Millisecond
)

var alphabet = []byte("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

type signalServer struct {
	mu     sync.Mutex
	rooms  map[string]*room
	iceURL []string
	turn   turnConfig
}

type turnConfig struct {
	URLs   []string
	Secret string
}

type room struct {
	Code         string
	Name         string
	PasswordHash string
	Capacity     int
	CreatedAt    time.Time
	Members      map[string]*member
	NextPeerID   int
}

type member struct {
	ID       string
	PeerID   int
	Name     string
	Token    string
	Host     bool
	SeenAt   time.Time
	Messages []signalMessage
}

type signalMessage struct {
	From string          `json:"from"`
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

type createRoomRequest struct {
	Name     string `json:"name"`
	Password string `json:"password"`
	Capacity int    `json:"capacity"`
}

type joinRoomRequest struct {
	Name     string `json:"name"`
	Password string `json:"password"`
}

type sendSignalRequest struct {
	To   string          `json:"to"`
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

type roomResponse struct {
	Code     string           `json:"code"`
	Name     string           `json:"name"`
	Capacity int              `json:"capacity"`
	Members  []memberResponse `json:"members"`
}

type memberResponse struct {
	ID     string `json:"id"`
	PeerID int    `json:"peer_id"`
	Name   string `json:"name"`
	Host   bool   `json:"host"`
}

type iceServerResponse struct {
	URLs       []string `json:"urls"`
	Username   string   `json:"username,omitempty"`
	Credential string   `json:"credential,omitempty"`
}

type sessionResponse struct {
	Room       roomResponse       `json:"room"`
	Member     memberResponse     `json:"member"`
	Token      string             `json:"token"`
	IceServers []iceServerResponse `json:"ice_servers,omitempty"`
}

type apiError struct {
	Error string `json:"error"`
}

func main() {
	address := strings.TrimSpace(os.Getenv("PIXEL_SIGNAL_ADDR"))
	if address == "" {
		address = defaultAddress
	}

	s := &signalServer{
		rooms:  make(map[string]*room),
		iceURL: splitURLs(os.Getenv("PIXEL_STUN_URLS")),
		turn: turnConfig{
			URLs:   splitURLs(os.Getenv("PIXEL_TURN_URLS")),
			Secret: strings.TrimSpace(os.Getenv("PIXEL_TURN_SECRET")),
		},
	}
	if len(s.turn.URLs) > 0 && s.turn.Secret == "" {
		log.Printf("TURN URLs ignored: PIXEL_TURN_SECRET is empty")
	}
	go s.reapExpiredRooms()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("POST /v1/rooms", s.createRoom)
	mux.HandleFunc("/v1/rooms/", s.roomRoute)

	server := &http.Server{
		Addr:              address,
		Handler:           securityHeaders(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      pollTimeout + 5*time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Printf("PIXEL signal listening on %s", address)
	log.Fatal(server.ListenAndServe())
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		next.ServeHTTP(w, r)
	})
}

func (s *signalServer) health(w http.ResponseWriter, _ *http.Request) {
	s.mu.Lock()
	count := len(s.rooms)
	s.mu.Unlock()
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "rooms": count})
}

func (s *signalServer) createRoom(w http.ResponseWriter, r *http.Request) {
	var request createRoomRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	name := cleanName(request.Name, "SALA")
	capacity := request.Capacity
	if capacity < 2 {
		capacity = 2
	}
	if capacity > 32 {
		capacity = 32
	}

	hostToken, err := randomToken(24)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "TOKEN_FAILED")
		return
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	s.cleanLocked(time.Now())
	code, err := s.newRoomCodeLocked()
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "ROOM_LIMIT")
		return
	}
	now := time.Now()
	host := &member{
		ID: "host", PeerID: 1, Name: "HOST", Token: hostToken, Host: true, SeenAt: now,
	}
	created := &room{
		Code: code, Name: name, PasswordHash: passwordHash(request.Password),
		Capacity: capacity, CreatedAt: now, Members: map[string]*member{"host": host}, NextPeerID: 2,
	}
	s.rooms[code] = created
	writeJSON(w, http.StatusCreated, s.sessionResponseLocked(created, host, hostToken))
}

func (s *signalServer) roomRoute(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.Trim(strings.TrimPrefix(r.URL.Path, "/v1/rooms/"), "/"), "/")
	if len(parts) == 0 || parts[0] == "" {
		writeError(w, http.StatusNotFound, "ROOM_NOT_FOUND")
		return
	}
	code := strings.ToUpper(parts[0])
	if len(parts) == 2 && parts[1] == "join" && r.Method == http.MethodPost {
		s.joinRoom(w, r, code)
		return
	}
	if len(parts) != 2 {
		writeError(w, http.StatusNotFound, "ROUTE_NOT_FOUND")
		return
	}
	switch parts[1] {
	case "heartbeat":
		if r.Method == http.MethodPost {
			s.heartbeat(w, r, code)
			return
		}
	case "signals":
		if r.Method == http.MethodGet {
			s.pollSignals(w, r, code)
			return
		}
	case "signal":
		if r.Method == http.MethodPost {
			s.sendSignal(w, r, code)
			return
		}
	case "leave":
		if r.Method == http.MethodPost {
			s.leaveRoom(w, r, code)
			return
		}
	case "info":
		if r.Method == http.MethodGet {
			s.roomInfo(w, r, code)
			return
		}
	}
	writeError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED")
}

func (s *signalServer) joinRoom(w http.ResponseWriter, r *http.Request, code string) {
	var request joinRoomRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	token, err := randomToken(24)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "TOKEN_FAILED")
		return
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	s.cleanLocked(now)
	room := s.rooms[code]
	if room == nil {
		writeError(w, http.StatusNotFound, "ROOM_NOT_FOUND")
		return
	}
	if !passwordMatches(room.PasswordHash, request.Password) {
		writeError(w, http.StatusForbidden, "BAD_PASSWORD")
		return
	}
	if len(room.Members) >= room.Capacity {
		writeError(w, http.StatusForbidden, "ROOM_FULL")
		return
	}
	memberID, err := s.newMemberIDLocked(room)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "MEMBER_LIMIT")
		return
	}
	joined := &member{
		ID: memberID, PeerID: room.NextPeerID, Name: cleanName(request.Name, "JOGADOR"), Token: token, SeenAt: now,
	}
	room.NextPeerID += 1
	room.Members[memberID] = joined
	s.broadcastMemberEventLocked(room, joined.ID, "peer_joined", memberView(joined))
	writeJSON(w, http.StatusOK, s.sessionResponseLocked(room, joined, token))
}

func (s *signalServer) heartbeat(w http.ResponseWriter, r *http.Request, code string) {
	s.mu.Lock()
	_, member, ok := s.memberForRequestLocked(code, r)
	s.mu.Unlock()
	if !ok {
		writeError(w, http.StatusUnauthorized, "INVALID_SESSION")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "member": member.ID})
}

func (s *signalServer) roomInfo(w http.ResponseWriter, r *http.Request, code string) {
	s.mu.Lock()
	room, _, ok := s.memberForRequestLocked(code, r)
	if !ok {
		s.mu.Unlock()
		writeError(w, http.StatusUnauthorized, "INVALID_SESSION")
		return
	}
	response := s.roomResponseLocked(room)
	s.mu.Unlock()
	writeJSON(w, http.StatusOK, response)
}

func (s *signalServer) sendSignal(w http.ResponseWriter, r *http.Request, code string) {
	var request sendSignalRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	if request.To == "" || !validClientSignalType(request.Type) || len(request.Data) == 0 {
		writeError(w, http.StatusBadRequest, "INVALID_SIGNAL")
		return
	}

	s.mu.Lock()
	room, sender, ok := s.memberForRequestLocked(code, r)
	if !ok {
		s.mu.Unlock()
		writeError(w, http.StatusUnauthorized, "INVALID_SESSION")
		return
	}
	recipient := room.Members[request.To]
	if recipient == nil {
		s.mu.Unlock()
		writeError(w, http.StatusNotFound, "MEMBER_NOT_FOUND")
		return
	}
	recipient.Messages = append(recipient.Messages, signalMessage{
		From: sender.ID, Type: request.Type, Data: request.Data,
	})
	s.mu.Unlock()
	writeJSON(w, http.StatusAccepted, map[string]any{"ok": true})
}

func (s *signalServer) pollSignals(w http.ResponseWriter, r *http.Request, code string) {
	deadline := time.Now().Add(pollTimeout)
	for {
		s.mu.Lock()
		_, member, ok := s.memberForRequestLocked(code, r)
		if !ok {
			s.mu.Unlock()
			writeError(w, http.StatusUnauthorized, "INVALID_SESSION")
			return
		}
		messages := member.Messages
		member.Messages = nil
		s.mu.Unlock()
		if len(messages) > 0 || time.Now().After(deadline) {
			writeJSON(w, http.StatusOK, map[string]any{"signals": messages})
			return
		}
		time.Sleep(pollInterval)
	}
}

func (s *signalServer) leaveRoom(w http.ResponseWriter, r *http.Request, code string) {
	s.mu.Lock()
	room, member, ok := s.memberForRequestLocked(code, r)
	if ok {
		delete(room.Members, member.ID)
		if member.Host || len(room.Members) == 0 {
			delete(s.rooms, code)
		} else {
			s.broadcastMemberEventLocked(room, member.ID, "peer_left", memberView(member))
		}
	}
	s.mu.Unlock()
	if !ok {
		writeError(w, http.StatusUnauthorized, "INVALID_SESSION")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *signalServer) memberForRequestLocked(code string, r *http.Request) (*room, *member, bool) {
	room := s.rooms[code]
	if room == nil {
		return nil, nil, false
	}
	token := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	if token == "" {
		return nil, nil, false
	}
	for _, member := range room.Members {
		if hmac.Equal([]byte(member.Token), []byte(token)) {
			member.SeenAt = time.Now()
			return room, member, true
		}
	}
	return nil, nil, false
}

func (s *signalServer) roomResponseLocked(room *room) roomResponse {
	members := make([]memberResponse, 0, len(room.Members))
	for _, member := range room.Members {
		members = append(members, memberView(member))
	}
	sort.Slice(members, func(i, j int) bool { return members[i].PeerID < members[j].PeerID })
	return roomResponse{Code: room.Code, Name: room.Name, Capacity: room.Capacity, Members: members}
}

func memberView(member *member) memberResponse {
	return memberResponse{ID: member.ID, PeerID: member.PeerID, Name: member.Name, Host: member.Host}
}

func (s *signalServer) sessionResponseLocked(room *room, member *member, token string) sessionResponse {
	return sessionResponse{
		Room: s.roomResponseLocked(room), Member: memberView(member), Token: token,
		IceServers: s.iceServers(member),
	}
}

func (s *signalServer) iceServers(member *member) []iceServerResponse {
	servers := make([]iceServerResponse, 0, 2)
	if len(s.iceURL) > 0 {
		servers = append(servers, iceServerResponse{URLs: s.iceURL})
	}
	if len(s.turn.URLs) == 0 || s.turn.Secret == "" {
		return servers
	}
	username := fmt.Sprintf("%d:%s", time.Now().Add(24*time.Hour).Unix(), member.ID)
	mac := hmac.New(sha1.New, []byte(s.turn.Secret))
	_, _ = mac.Write([]byte(username))
	servers = append(servers, iceServerResponse{
		URLs: s.turn.URLs, Username: username, Credential: base64.StdEncoding.EncodeToString(mac.Sum(nil)),
	})
	return servers
}

func (s *signalServer) broadcastMemberEventLocked(room *room, exceptID, eventType string, view memberResponse) {
	payload, err := json.Marshal(view)
	if err != nil {
		return
	}
	for id, recipient := range room.Members {
		if id == exceptID {
			continue
		}
		recipient.Messages = append(recipient.Messages, signalMessage{
			From: "server", Type: eventType, Data: payload,
		})
	}
}

func (s *signalServer) newRoomCodeLocked() (string, error) {
	for range 32 {
		code, err := randomCode(8)
		if err != nil {
			return "", err
		}
		if _, used := s.rooms[code]; !used {
			return code, nil
		}
	}
	return "", errors.New("room code collision")
}

func (s *signalServer) newMemberIDLocked(room *room) (string, error) {
	for range 32 {
		id, err := randomCode(10)
		if err != nil {
			return "", err
		}
		id = "peer_" + id
		if _, used := room.Members[id]; !used {
			return id, nil
		}
	}
	return "", errors.New("member id collision")
}

func (s *signalServer) reapExpiredRooms() {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		s.mu.Lock()
		s.cleanLocked(time.Now())
		s.mu.Unlock()
	}
}

func (s *signalServer) cleanLocked(now time.Time) {
	for code, room := range s.rooms {
		for id, member := range room.Members {
			if now.Sub(member.SeenAt) > roomTTL {
				delete(room.Members, id)
				if !member.Host {
					s.broadcastMemberEventLocked(room, id, "peer_left", memberView(member))
				}
			}
		}
		if _, hostPresent := room.Members["host"]; !hostPresent || len(room.Members) == 0 {
			delete(s.rooms, code)
		}
	}
}

func randomToken(bytes int) (string, error) {
	buffer := make([]byte, bytes)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buffer), nil
}

func randomCode(length int) (string, error) {
	buffer := make([]byte, length)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}
	for i, value := range buffer {
		buffer[i] = alphabet[int(value)%len(alphabet)]
	}
	return string(buffer), nil
}

func passwordHash(password string) string {
	if password == "" {
		return ""
	}
	salt, err := randomToken(16)
	if err != nil {
		return ""
	}
	sum := sha256.Sum256([]byte(salt + ":" + password))
	return salt + ":" + base64.RawURLEncoding.EncodeToString(sum[:])
}

func passwordMatches(stored, password string) bool {
	if stored == "" {
		return password == ""
	}
	parts := strings.Split(stored, ":")
	if len(parts) != 2 {
		return false
	}
	sum := sha256.Sum256([]byte(parts[0] + ":" + password))
	expected := parts[0] + ":" + base64.RawURLEncoding.EncodeToString(sum[:])
	return hmac.Equal([]byte(stored), []byte(expected))
}

func cleanName(value, fallback string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return fallback
	}
	if len(value) > 24 {
		return value[:24]
	}
	return value
}

func validClientSignalType(value string) bool {
	switch value {
	case "offer", "answer", "candidate", "bye":
		return true
	default:
		return false
	}
}

func splitURLs(value string) []string {
	urls := make([]string, 0)
	for _, entry := range strings.Split(value, ",") {
		if url := strings.TrimSpace(entry); url != "" {
			urls = append(urls, url)
		}
	}
	return urls
}

func decodeJSON(w http.ResponseWriter, r *http.Request, target any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyBytes)
	defer r.Body.Close()
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		writeError(w, http.StatusBadRequest, "BAD_JSON")
		return false
	}
	return true
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, apiError{Error: message})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
