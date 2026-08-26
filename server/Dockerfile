FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY cmd ./cmd
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /pixel-signal ./cmd/pixel-signal

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /pixel-signal /pixel-signal
EXPOSE 8787
USER nonroot:nonroot
ENTRYPOINT ["/pixel-signal"]
