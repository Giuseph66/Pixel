#!/usr/bin/env python3
"""Reachability checker for PIXEL rooms.

Rebuilds every room exactly the way levels.gd paints it, then runs a breadth
first search over the real player physics — the constants below are copied
from player.gd — to answer one question per room: can you actually get from
P to X without touching a spike?

The search ignores coyote time and the jump buffer, so it is slightly stricter
than the running game: anything it can solve, a player can solve.

    python3 tools/verify_rooms.py              # check every room
    python3 tools/verify_rooms.py 7 8          # check only rooms 7 and 8
    python3 tools/verify_rooms.py 7 --show     # print the room as ASCII too

Rooms 1-6 are known playable by hand, so they double as a test of the checker:
if it cannot beat those, the checker is wrong, not the level.
"""

import sys
from collections import deque

COLS, ROWS, TILE = 60, 32, 8

# ---------------------------------------------------------------- painting ---

def blank():
    g = [["." for _ in range(COLS)] for _ in range(ROWS)]
    for x in range(COLS):
        g[0][x] = "#"
        g[ROWS - 1][x] = "#"
    for y in range(ROWS):
        g[y][0] = "#"
        g[y][COLS - 1] = "#"
    return g


def rect(g, x, y, w, h, ch):
    for j in range(y, y + h):
        if 0 <= j < ROWS:
            for i in range(x, x + w):
                if 0 <= i < COLS:
                    g[j][i] = ch


def put(g, x, y, ch):
    if 0 <= x < COLS and 0 <= y < ROWS:
        g[y][x] = ch


def puts(g, points, ch):
    for px, py in points:
        put(g, px, py, ch)


# ------------------------------------------------------- physics, player.gd ---

DT = 1.0 / 60.0
W, H = 6.0, 10.0
HW, HH = W / 2, H / 2

RUN_SPEED = 112.0
ACCEL_GROUND, ACCEL_AIR = 1000.0, 640.0
FRICTION_GROUND, FRICTION_AIR = 1250.0, 260.0
GRAVITY_UP, GRAVITY_DOWN, MAX_FALL = 900.0, 1180.0, 330.0
JUMP_VELOCITY, JUMP_CUT = -262.0, 0.42
WALL_SLIDE_SPEED, WALL_CLING = 58.0, 24.0
WALL_JUMP_X, WALL_JUMP_Y = 152.0, -252.0
SPRING_VELOCITY = -450.0

# Handy derived numbers when placing geometry:
#   full jump climbs 38px (4.7 tiles) and carries 61px (7.6 tiles)
#   a spring climbs 112px (14 tiles)
#   a wall jump climbs 35px and pushes 152px/s sideways


def move_toward(v, target, delta):
    if abs(target - v) <= delta:
        return target
    return v + (delta if target > v else -delta)


class World:
    def __init__(self, grid):
        self.g = grid
        self.solid = [[c == "#" for c in row] for row in grid]
        self.oneway = [[c == "-" for c in row] for row in grid]
        self.springs = [(x, y) for y in range(ROWS) for x in range(COLS)
                        if grid[y][x] == "J"]
        self.doors = [(x, y) for y in range(ROWS) for x in range(COLS)
                      if grid[y][x] == "X"]

    def solid_overlap(self, cx, cy):
        x0, x1 = cx - HW, cx + HW
        y0, y1 = cy - HH, cy + HH
        for ty in range(int(y0 // TILE), int((y1 - 1e-9) // TILE) + 1):
            for tx in range(int(x0 // TILE), int((x1 - 1e-9) // TILE) + 1):
                if not (0 <= tx < COLS and 0 <= ty < ROWS):
                    return True
                if self.solid[ty][tx]:
                    return True
        return False

    def oneway_land(self, cx, prev_y, new_y):
        """Top of the highest one-way slab this fall crosses, or None."""
        tx0 = int((cx - HW) // TILE)
        tx1 = int((cx + HW - 1e-9) // TILE)
        best = None
        for ty in range(max(0, int(prev_y // TILE) - 1),
                        min(ROWS, int(new_y // TILE) + 3)):
            for tx in range(tx0, tx1 + 1):
                if not (0 <= tx < COLS) or not self.oneway[ty][tx]:
                    continue
                top = ty * TILE
                if prev_y + HH <= top + 1 and new_y + HH >= top:
                    if best is None or top < best:
                        best = top
        return best

    def spike_hit(self, cx, cy):
        x0, x1 = cx - HW, cx + HW
        y0, y1 = cy - HH, cy + HH
        for ty in range(max(0, int(y0 // TILE) - 1), min(ROWS, int(y1 // TILE) + 2)):
            for tx in range(max(0, int(x0 // TILE) - 1), min(COLS, int(x1 // TILE) + 2)):
                c = self.g[ty][tx]
                if c == "^":
                    sy0, sy1 = ty * TILE + 4, ty * TILE + 8
                elif c == "v":
                    sy0, sy1 = ty * TILE, ty * TILE + 4
                else:
                    continue
                if x0 < tx * TILE + 7 and x1 > tx * TILE + 1 and y0 < sy1 and y1 > sy0:
                    return True
        return False

    def spring_hit(self, cx, cy, vy):
        if vy < -10.0:
            return False
        x0, x1 = cx - HW, cx + HW
        y0, y1 = cy - HH, cy + HH
        for tx, ty in self.springs:
            if (x0 < tx * TILE + 8 and x1 > tx * TILE
                    and y0 < ty * TILE + 8 and y1 > ty * TILE + 3
                    and cy < ty * TILE + 5.5):
                return True
        return False

    def door_hit(self, cx, cy):
        x0, x1 = cx - HW, cx + HW
        y0, y1 = cy - HH, cy + HH
        for tx, ty in self.doors:
            if (x0 < tx * TILE + 12 and x1 > tx * TILE + 4
                    and y0 < ty * TILE + 6 and y1 > ty * TILE - 6):
                return True
        return False


def step(world, s, inp, jump, prev_jump):
    x, y, vx, vy, on_floor, wall_n = s

    target = inp * RUN_SPEED
    if inp != 0:
        rate = ACCEL_GROUND if on_floor else ACCEL_AIR
    else:
        rate = FRICTION_GROUND if on_floor else FRICTION_AIR
    vx = move_toward(vx, target, rate * DT)

    wall_dir = 0
    if not on_floor and wall_n != 0:
        d = -wall_n
        if not (inp != 0 and inp != d):
            wall_dir = d

    vy += (GRAVITY_UP if vy < 0 else GRAVITY_DOWN) * DT
    if wall_dir != 0 and vy > 0:
        vy = min(vy, WALL_SLIDE_SPEED)
        vx = wall_dir * WALL_CLING
    else:
        vy = min(vy, MAX_FALL)

    if jump and not prev_jump:
        if on_floor:
            vy = JUMP_VELOCITY
        elif wall_dir != 0:
            vy = WALL_JUMP_Y
            vx = -wall_dir * WALL_JUMP_X
    if prev_jump and not jump and vy < 0:
        vy *= JUMP_CUT

    n = max(1, int(max(abs(vx), abs(vy)) * DT / 2.0) + 1)
    on_floor = False
    wall_n = 0
    for _ in range(n):
        nx = x + vx * DT / n
        if world.solid_overlap(nx, y):
            if vx > 0:
                nx = int((nx + HW) // TILE) * TILE - HW
                wall_n = -1
            elif vx < 0:
                nx = (int((nx - HW) // TILE) + 1) * TILE + HW
                wall_n = 1
            vx = 0.0
        x = nx

        ny = y + vy * DT / n
        if world.solid_overlap(x, ny):
            if vy > 0:
                ny = int((ny + HH) // TILE) * TILE - HH
                on_floor = True
            elif vy < 0:
                ny = (int((ny - HH) // TILE) + 1) * TILE + HH
            vy = 0.0
        elif vy > 0:
            top = world.oneway_land(x, y, ny)
            if top is not None:
                ny = top - HH
                vy = 0.0
                on_floor = True
        y = ny

    if world.spring_hit(x, y, vy):
        vy = SPRING_VELOCITY

    return [x, y, vx, vy, on_floor, wall_n]


def find(grid, ch):
    for ty in range(ROWS):
        for tx in range(COLS):
            if grid[ty][tx] == ch:
                return tx, ty
    return None


HOLD = 2            # frames one action is held before the search branches


def solve(grid, budget=500000):
    world = World(grid)
    start = find(grid, "P")
    if start is None:
        return "NO SPAWN", 0
    if not world.doors:
        return "NO EXIT", 0

    s0 = [start[0] * TILE + TILE / 2, start[1] * TILE + TILE - HH, 0.0, 0.0, True, 0]

    def key(s, jump):
        return (round(s[0]), round(s[1]), int(s[2] // 12), int(s[3] // 15), jump)

    seen = {key(s0, False)}
    q = deque([(s0, False)])
    expanded = 0

    while q and expanded < budget:
        s, prev_jump = q.popleft()
        expanded += 1
        for inp in (-1, 0, 1):
            for jump in (False, True):
                cur, pj, dead = s, prev_jump, False
                for _ in range(HOLD):
                    cur = step(world, cur, inp, jump, pj)
                    pj = jump
                    if world.spike_hit(cur[0], cur[1]):
                        dead = True
                        break
                    if world.door_hit(cur[0], cur[1]):
                        return "SOLVABLE", expanded
                if dead:
                    continue
                k = key(cur, jump)
                if k in seen:
                    continue
                seen.add(k)
                q.append((cur, jump))
    return ("UNREACHABLE" if expanded < budget else "TIMEOUT"), expanded


def warnings(grid):
    """Entities placed with nothing holding them up."""
    out = []
    for ty in range(ROWS):
        for tx in range(COLS):
            c = grid[ty][tx]
            if c in ("J", "S", "^"):
                below = grid[ty + 1][tx] if ty + 1 < ROWS else "#"
                if below not in ("#", "-"):
                    out.append(f"    {c} at ({tx},{ty}) floats, nothing under it")
            elif c == "v":
                above = grid[ty - 1][tx] if ty > 0 else "#"
                if above not in ("#", "-"):
                    out.append(f"    v at ({tx},{ty}) floats, nothing over it")
            elif c == "X":
                below = grid[ty + 1][tx] if ty + 1 < ROWS else "#"
                if below not in ("#", "-"):
                    out.append(f"    X at ({tx},{ty}) has no floor to stand on")
            elif c == "J":
                pass
    # A spring firing into solid ground goes nowhere: check the 14 tiles above.
    for ty in range(ROWS):
        for tx in range(COLS):
            if grid[ty][tx] != "J":
                continue
            for up in range(1, 15):
                if ty - up < 0:
                    break
                if grid[ty - up][tx] == "#":
                    out.append(f"    J at ({tx},{ty}) fires into solid tile "
                               f"at ({tx},{ty - up})")
                    break
    return out


def render(grid, name):
    print(f"\n--- {name} " + "-" * max(0, 54 - len(name)))
    print("     " + "".join(str(i // 10 % 10) for i in range(COLS)))
    print("     " + "".join(str(i % 10) for i in range(COLS)))
    for y, row in enumerate(grid):
        print(f"{y:3d}  " + "".join(row))


# ------------------------------------------------------- rooms, levels.gd ---

def level_1():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    rect(g, 16, 25, 7, 2, "#")
    rect(g, 27, 22, 8, 5, "#")
    rect(g, 38, 19, 15, 8, "#")
    puts(g, [(19, 24), (30, 21), (44, 18)], "o")
    put(g, 4, 26, "P")
    put(g, 48, 18, "X")
    return g


def level_2():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    for start, width in [(13, 5), (27, 6), (43, 5)]:
        rect(g, start, 27, width, 3, ".")
        rect(g, start, 30, width, 1, "^")
    rect(g, 10, 23, 5, 1, "-")
    rect(g, 35, 23, 6, 1, "-")
    rect(g, 17, 20, 6, 1, "#")
    rect(g, 50, 24, 10, 3, "#")
    puts(g, [(12, 22), (19, 19), (37, 22)], "o")
    put(g, 4, 26, "P")
    put(g, 53, 23, "X")
    return g


def level_3():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    rect(g, 6, 18, 39, 3, "#")
    puts(g, [(24, 21), (25, 21), (28, 21), (29, 21)], "v")
    rect(g, 12, 26, 3, 1, "^")
    rect(g, 20, 26, 3, 1, "^")
    rect(g, 34, 26, 3, 1, "^")
    rect(g, 46, 23, 14, 4, "#")
    puts(g, [(13, 25), (21, 25), (35, 25)], "o")
    put(g, 3, 26, "P")
    put(g, 49, 22, "X")
    return g


def level_4():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    rect(g, 22, 20, 9, 1, "#")
    rect(g, 10, 23, 9, 1, "#")
    puts(g, [(23, 19), (11, 22), (50, 26)], "o")
    puts(g, [(26, 19), (14, 22), (22, 26), (44, 26)], "S")
    put(g, 3, 26, "P")
    put(g, 55, 26, "X")
    return g


def level_5():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    rect(g, 22, 8, 15, 1, "-")
    rect(g, 4, 16, 13, 1, "-")
    rect(g, 44, 16, 13, 1, "-")
    rect(g, 20, 20, 13, 1, "#")
    puts(g, [(8, 26), (50, 26), (28, 19)], "J")
    puts(g, [(26, 7), (8, 15), (50, 15), (22, 19)], "o")
    put(g, 3, 26, "P")
    put(g, 32, 7, "X")
    return g


def level_6():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    rect(g, 17, 7, 1, 18, "#")
    rect(g, 12, 9, 1, 16, "#")
    rect(g, 4, 8, 9, 1, "#")
    rect(g, 17, 6, 12, 1, "#")
    rect(g, 34, 6, 13, 1, "#")
    rect(g, 30, 26, 5, 1, "^")
    rect(g, 44, 26, 3, 1, "^")
    puts(g, [(14, 13), (15, 19), (22, 5), (52, 26)], "o")
    put(g, 24, 26, "S")
    put(g, 3, 26, "P")
    put(g, 40, 5, "X")
    return g


def level_7():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    for px, width in [(14, 5), (28, 5), (44, 5)]:
        rect(g, px, 27, width, 3, ".")
        rect(g, px, 30, width, 1, "^")
    rect(g, 8, 23, 6, 1, "-")
    rect(g, 19, 23, 6, 1, "-")
    rect(g, 30, 23, 6, 1, "-")
    puts(g, [(10, 22), (21, 22), (32, 22), (52, 26)], "o")
    puts(g, [(10, 26), (24, 26), (38, 26)], "S")
    put(g, 3, 26, "P")
    put(g, 54, 26, "X")
    return g


def level_8():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    rect(g, 4, 16, 17, 1, "-")
    rect(g, 14, 6, 21, 1, "-")
    rect(g, 42, 16, 14, 1, "-")
    puts(g, [(8, 26), (18, 15), (48, 26)], "J")
    puts(g, [(6, 15), (24, 5), (32, 5), (50, 15)], "o")
    put(g, 3, 26, "P")
    put(g, 30, 5, "X")
    return g


def level_9():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    rect(g, 10, 24, 7, 1, "-")
    rect(g, 21, 21, 7, 1, "-")
    rect(g, 32, 18, 7, 1, "-")
    rect(g, 43, 15, 7, 1, "-")
    rect(g, 52, 12, 7, 1, "-")
    puts(g, [(14, 23), (25, 20), (36, 17), (47, 14)], "S")
    puts(g, [(11, 23), (22, 20), (33, 17), (44, 14), (57, 11)], "o")
    put(g, 3, 26, "P")
    put(g, 54, 11, "X")
    return g


def level_10():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    rect(g, 6, 20, 6, 1, "#")
    rect(g, 14, 23, 8, 1, "#")
    rect(g, 24, 20, 6, 1, "#")
    rect(g, 32, 23, 8, 1, "#")
    rect(g, 42, 20, 6, 1, "#")
    rect(g, 50, 23, 10, 1, "#")
    puts(g, [(8, 26), (18, 26), (28, 26), (38, 26), (48, 26)], "^")
    puts(g, [(10, 19), (26, 19), (44, 19), (20, 22), (40, 22)], "o")
    put(g, 3, 26, "P")
    put(g, 55, 22, "X")
    return g


def level_11():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    rect(g, 14, 26, 3, 1, "^")
    rect(g, 22, 18, 13, 1, "-")
    rect(g, 20, 8, 13, 1, "-")
    puts(g, [(28, 26), (26, 17)], "J")
    puts(g, [(24, 17), (32, 17), (22, 7), (31, 7), (8, 26)], "o")
    put(g, 3, 26, "P")
    put(g, 26, 7, "X")
    return g


def level_12():
    g = blank()
    rect(g, 0, 27, COLS, 5, "#")
    rect(g, 8, 26, 2, 1, "^")
    rect(g, 20, 8, 1, 17, "#")
    rect(g, 25, 8, 1, 17, "#")
    rect(g, 25, 7, 12, 1, "#")
    rect(g, 42, 7, 11, 1, "#")
    rect(g, 36, 14, 11, 1, "-")
    puts(g, [(14, 26), (45, 6)], "S")
    put(g, 40, 26, "J")
    puts(g, [(22, 15), (28, 6), (34, 6), (40, 13), (50, 6)], "o")
    put(g, 3, 26, "P")
    put(g, 48, 6, "X")
    return g


LEVELS = [level_1, level_2, level_3, level_4, level_5, level_6,
          level_7, level_8, level_9, level_10, level_11, level_12]


def main():
    which = [int(a) for a in sys.argv[1:] if a.isdigit()]
    show = "--show" in sys.argv
    bad = 0
    for i, fn in enumerate(LEVELS, 1):
        if which and i not in which:
            continue
        g = fn()
        if show:
            render(g, f"room {i}")
        verdict, expanded = solve(g)
        ok = verdict == "SOLVABLE"
        bad += 0 if ok else 1
        print(f"{'ok  ' if ok else 'FAIL'} room {i:2d}  {verdict:12s} "
              f"{expanded:7d} states")
        for w in warnings(g):
            print(w)
    print(f"\n{bad} room(s) need work" if bad else "\nall rooms clear")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
