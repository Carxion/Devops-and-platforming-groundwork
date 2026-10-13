#!/usr/bin/env bats
# Tests for the patterns in bash/03-regex.md. Each pattern must match every
# "good" string and none of the "bad" ones. Run: bats bash/tests
#
# Patterns are anchored here (^...$) to test them as validators; the doc
# explains when to drop the anchors for searching.

# matches FLAVOR PATTERN STRING...: every STRING matches (FLAVOR is E or P).
matches() {
  local flavor="$1" pattern="$2" s
  shift 2
  for s in "$@"; do
    printf '%s\n' "$s" | grep -q"$flavor" -- "$pattern" || {
      echo "expected match: '$s'"
      return 1
    }
  done
}

# rejects FLAVOR PATTERN STRING...: no STRING matches.
rejects() {
  local flavor="$1" pattern="$2" s
  shift 2
  for s in "$@"; do
    if printf '%s\n' "$s" | grep -q"$flavor" -- "$pattern"; then
      echo "expected no match: '$s'"
      return 1
    fi
  done
}

@test "IPv4, loose" {
  p='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
  matches E "$p" 203.0.113.9 10.0.0.1 999.1.1.1
  rejects E "$p" 10.0.0 10.0.0.1.5 a.b.c.d 1234.1.1.1
}

@test "IPv4, strict" {
  p='^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$'
  matches E "$p" 0.0.0.0 10.0.0.1 192.168.1.254 255.255.255.255 172.16.99.100
  rejects E "$p" 256.1.1.1 1.1.1.300 01.2.3.4 10.0.0 999.1.1.1
}

@test "IPv4 CIDR" {
  p='^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(3[0-2]|[12]?[0-9])$'
  matches E "$p" 10.0.0.0/16 0.0.0.0/0 192.168.1.0/24 10.1.2.3/32
  rejects E "$p" 10.0.0.0/33 10.0.0.0 10.0.0.0/ 300.0.0.0/8
}

@test "ISO 8601 date" {
  p='^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'
  matches E "$p" 2026-10-13 2024-02-29 1999-12-31
  rejects E "$p" 2026-13-01 2026-00-10 2026-10-32 26-10-13 2026/10/13
}

@test "log timestamp" {
  p='^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?$'
  matches E "$p" 2026-10-13T08:00:01Z "2026-10-13 08:00:01" 2026-10-13T08:00:01.123+05:30 2026-10-13T08:00:01-0800
  rejects E "$p" 2026-10-13 2026-10-13T8:00:01Z 2026-10-13T08:00:01+5
}

@test "email (practical)" {
  p='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  matches E "$p" platform-team@example.com first.last+tag@sub.example.org
  rejects E "$p" no-at-sign.example.com user@localhost "@example.com" "user@example.c"
}

@test "semantic version" {
  p='^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
  matches E "$p" 1.4.2 v2.0.0 0.162.0 1.0.0-rc.1 1.0.0+build.5 2.1.3-beta+exp.sha.5114f85
  rejects E "$p" 1.4 01.2.3 1.2.3.4 v1 1.2.x
}

@test "UUID" {
  p='^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
  matches E "$p" 123e4567-e89b-12d3-a456-426614174000 00000000-0000-0000-0000-000000000000
  rejects E "$p" 123e4567e89b12d3a456426614174000 123e4567-e89b-12d3-a456-42661417400 g23e4567-e89b-12d3-a456-426614174000
}

@test "Linux user name" {
  p='^[a-z_][a-z0-9_-]{0,31}$'
  matches E "$p" deploy _svc web-01 a
  rejects E "$p" Deploy 1user "has space" "" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
}

@test "hostname (RFC 1123)" {
  p='^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$'
  matches E "$p" web-01 db.internal a 1host api.example.com
  rejects E "$p" -web web- web_01 "web 01" web..example ".example"
}

@test "HOST:PORT" {
  p='^(\[[0-9A-Fa-f:]+\]|[A-Za-z0-9.-]+):([0-9]{1,5})$'
  matches E "$p" localhost:8080 10.0.0.5:5432 "[::1]:443" db.internal:3306
  rejects E "$p" localhost 8080 "host:" "::1:443" "host:123456"
}

@test "container image reference" {
  p='^[a-z0-9]+([._/-][a-z0-9]+)*(:[0-9]+)?(/[a-z0-9]+([._-][a-z0-9]+)*)*(:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127})?(@sha256:[a-f0-9]{64})?$'
  digest=$(printf 'a%.0s' {1..64})
  matches E "$p" nginx nginx:1.27 ghcr.io/stefanprodan/podinfo:6.15.0 localhost:5000/team/app:v1 \
    "registry.example.com/app@sha256:${digest}" "grafana/k6:2.3.0@sha256:${digest}"
  rejects E "$p" Nginx "app:" "app@sha256:short" "app:-bad"
}

@test "AWS access key ID" {
  p='\b(AKIA|ASIA)[A-Z0-9]{16}\b'
  matches E "$p" AKIAIOSFODNN7EXAMPLE "key=ASIAIOSFODNN7EXAMPLE end"
  rejects E "$p" AKIAIOSFODNN7EXAMPL XAKIAIOSFODNN7EXAMPLEX akiaiosfodnn7example
}

@test "HTTP 4xx and 5xx" {
  p='^[45][0-9]{2}$'
  matches E "$p" 404 500 503 429
  rejects E "$p" 200 302 4040 50
}

@test "log level" {
  p='\b(FATAL|ERROR|WARN(ING)?)\b'
  matches E "$p" "2026-10-13 ERROR db timeout" "WARN slow query" "level=WARNING msg=x" "FATAL: out of memory"
  rejects E "$p" "INFO started" "ERRORS=0" "warning lowercase"
}

@test "comment or blank line" {
  p='^[[:space:]]*(#|$)'
  matches E "$p" "# comment" "   # indented" "" "    "
  rejects E "$p" "PermitRootLogin no" "Port 22 # trailing"
}

@test "sed: set a commented-out setting" {
  run sed -E 's/^[[:space:]]*#?[[:space:]]*(PasswordAuthentication)[[:space:]].*/\1 no/' <<'EOF'
#PasswordAuthentication yes
  PasswordAuthentication yes
PermitRootLogin yes
EOF
  [ "${lines[0]}" = "PasswordAuthentication no" ]
  [ "${lines[1]}" = "PasswordAuthentication no" ]
  [ "${lines[2]}" = "PermitRootLogin yes" ]
}

@test "greedy versus negated class" {
  s='say "hi" and "bye"'
  [ "$(grep -oE '".*"' <<<"$s")" = '"hi" and "bye"' ]
  [ "$(grep -oE '"[^"]*"' <<<"$s" | head -1)" = '"hi"' ]
  [ "$(grep -oP '".*?"' <<<"$s" | head -1)" = '"hi"' ]
}

@test "PCRE extraction with \\K and lookbehind" {
  [ "$(grep -oP 'duration=\K[0-9.]+' <<<'op=put duration=0.250s')" = "0.250" ]
  [ "$(grep -oP '(?<=user=)[^ ]+' <<<'user=alice id=7')" = "alice" ]
  [ "$(grep -oP '\d+(?=ms)' <<<'took 250ms')" = "250" ]
}

@test "\\d is not a digit in ERE" {
  # In ERE, \d is undefined; GNU grep 3.8+ warns and treats it as the letter d.
  run bash -c "printf '123\n' | grep -E '\\d' 2>/dev/null"
  [ "$status" -ne 0 ]
}

@test "Bash =~ with BASH_REMATCH" {
  re='^([A-Za-z_][A-Za-z0-9_]*)=(.*)$'
  [[ 'DB_HOST=db.internal' =~ $re ]]
  [ "${BASH_REMATCH[1]}" = DB_HOST ]
  [ "${BASH_REMATCH[2]}" = db.internal ]
  # A quoted pattern is matched literally, not as a regex.
  ! [[ 'DB_HOST=x' =~ "^DB" ]] || [[ '^DB' == "^DB" ]]
}
