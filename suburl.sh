
#!/bin/bash 

set -o pipefail

WORDLIST=""
RESOLVERS=""
PUREDNS_RATE="${PUREDNS_RATE:-700}"
HTTPX_THREADS="${HTTPX_THREADS:-100}"
GAU_THREADS="${GAU_THREADS:-500}"

DOMAIN=""

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BLUE=$'\033[34m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""
fi

log_info()  { echo "${C_BLUE}[i]${C_RESET}  $*"; }
log_ok()    { echo "${C_GREEN}[+]${C_RESET}  $*"; }
log_warn()  { echo "${C_YELLOW}[-]${C_RESET}  $*"; }
log_err()   { echo "${C_RED}[!]${C_RESET}  $*"; }
count()     { [[ -f "$1" ]] && wc -l "$1"  || echo 0; }
step() {
  echo
  echo "${C_BOLD}${C_CYAN}=> $*${C_RESET}"
  printf "%s\n" "--------------------------------------------------"
}



REQUIRED_TOOLS_LIST="subfinder, waybackurls, waymore ,github-subdomains, puredns, tlsx, httpx, gauplus, katana, uro, gf, anew, unfurl"
usage() {
  cat <<PP
Usage:
  $0 -d  <domain>       [-w <wordlist>] [-r <resolvers>]
  for domain in (cat domains_list.txt);do $0 -d  \$domain  [-w <wordlist>] [-r <resolvers>] ;done

Required tools (assumed installed):
  $REQUIRED_TOOLS_LIST
PP
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d)  DOMAIN="$2"; shift 2;;
    -w)  WORDLIST="$2"; shift 2;;
    -r)  RESOLVERS="$2"; shift 2;;
    *)  usage ;;
  esac
done

if [[ -z "$DOMAIN" ]]; then
  usage
fi

for tool in subfinder waybackurls waymore github-subdomains puredns tlsx httpx gauplus katana uro gf anew unfurl; do
    command -v $tool >/dev/null 2>&1 && ls >/dev/null 2>&1 || log_err "$tool: Not Installed"
done

mkdir -p "$DOMAIN"

step "CONFIG"
log_info "output dir     : $DOMAIN"
log_info "domains input  : $DOMAIN"
log_info "wordlist       : ${WORDLIST:-NOT SET}"
log_info "resolvers      : ${RESOLVERS:-NOT SET}"
[[ -n "${GITHUB_TOKEN:-}"  ]]  || log_info "GITHUB_TOKEN   : NOT SET"

step "SUBDOMAIN ENUMERATION & URL DISCOVERY"

  subfinder -d "$DOMAIN" -all -silent -recursive -o "$DOMAIN/subfinder.txt" >/dev/null 2>&1 &
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    github-subdomains -d "$DOMAIN" -t "$GITHUB_TOKEN" -o "$DOMAIN/ghsubs.txt" >/dev/null 2>&1 &
  fi

  if [[ -n "$WORDLIST" && -n "$RESOLVERS" ]]; then
    puredns bruteforce "$WORDLIST" "$DOMAIN" -r "$RESOLVERS" --rate-limit "$PUREDNS_RATE" -w "$DOMAIN/puredns.txt" >/dev/null 2>&1 &
  fi
  tlsx -u "$DOMAIN" -san -cn -resp-only -silent -o "$DOMAIN/tlsx.txt" >/dev/null 2>&1 & 
  CRT_RESPONSE=$(curl -s --max-time 20 "https://crt.sh/?q=%25.$DOMAIN&output=json")
  if echo "$CRT_RESPONSE" | jq -e . >/dev/null 2>&1; then
      echo "$CRT_RESPONSE" | jq -r '.[].name_value' | sed 's/\*\.//g' \
          | grep -E "(^|\.)$DOMAIN$" | sort -u > "$DOMAIN/crt.txt"
  else
      log_warn "crt.sh: 502 Bad Gateway"
      > "$DOMAIN/crt.txt"
  fi
  wait
  cat  "$DOMAIN/subfinder.txt" "$DOMAIN/ghsubs.txt" "$DOMAIN/crt.txt" "$DOMAIN/puredns.txt" "$DOMAIN/tlsx.txt" | anew "$DOMAIN/subs.txt" > /dev/null ; rm "$DOMAIN/crt.txt" "$DOMAIN/subfinder.txt" "$DOMAIN/ghsubs.txt" "$DOMAIN/puredns.txt" "$DOMAIN/tlsx.txt" 2> /dev/null


  echo "$DOMAIN" | gauplus -subs -t "$GAU_THREADS" -random-agent > "$DOMAIN/gauplus.txt" 2>/dev/null &
  echo "$DOMAIN" | waybackurls  > "$DOMAIN/waybackurls.txt" 2>/dev/null &
  waymore -i "$DOMAIN" -mode U -oU "$DOMAIN/waymore.txt" >/dev/null 1>&2 &
  katana -u "$DOMAIN/subs.txt" -kf all -silent -o "$DOMAIN/katana.txt" >/dev/null 2>&1 &
  wait

  cat "$DOMAIN/gauplus.txt" "$DOMAIN/waybackurls.txt" "$DOMAIN/waymore.txt" "$DOMAIN/katana.txt"\
    | tr -d '\r' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | grep -E '^https?://' > "$DOMAIN/all_urls.txt" 2> /dev/null; rm "$DOMAIN/gauplus.txt" "$DOMAIN/waybackurls.txt" "$DOMAIN/waymore.txt" "$DOMAIN/katana.txt"  2> /dev/null
  cat "$DOMAIN/all_urls.txt" | unfurl -u domains | anew "$DOMAIN/subs_t.txt"

step "FILTERING"

  httpx -l "$DOMAIN/subs_t.txt" -silent -sc -t "$HTTPX_THREADS" -o "$DOMAIN/subs.txt" > /dev/null 2>&1

  grep -E '\.js([?#].*)?$' "$DOMAIN/all_urls.txt" | uro | anew "$DOMAIN/js.txt" > /dev/null
  cat "$DOMAIN/all_urls.txt" | gf interestingEXT | anew "$DOMAIN/interesting.txt" > /dev/null
  cat "$DOMAIN/all_urls.txt" | gf ssrf | anew "$DOMAIN/ssrf.txt" > /dev/null
  cat "$DOMAIN/all_urls.txt" | gf sqli | anew "$DOMAIN/sqli.txt" > /dev/null
  rm  "$DOMAIN/all_urls.txt"


step "SUMMARY"

  log_ok "$DOMAIN/subs.txt: $(count "$DOMAIN/subs.txt") lines"
  log_ok "$DOMAIN/interesting.txt: $(count "$DOMAIN/interesting.txt") lines"
  log_ok "$DOMAIN/js.txt: $(count "$DOMAIN/js.txt") lines"
  log_ok "$DOMAIN/ssrf.txt: $(count "$DOMAIN/ssrf.txt") lines"
  log_ok "$DOMAIN/sqli.txt: $(count "$DOMAIN/sqli.txt") lines"
  echo "===================================================="

log_ok "done."
