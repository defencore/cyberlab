# Script Name: Mikrotik CSS326-24G-2S+ Honeypot Web Interface
# Description:
# This script creates a honeypot designed to mimic the login page of a Mikrotik CSS326-24G-2S+ switch. 
# The purpose of the honeypot is to capture potential unauthorized access attempts by emulating a real 
# web interface, allowing for analysis of attacker behavior. The web page is styled and structured to 
# closely resemble the legitimate Mikrotik login page, but all input is captured and logged for further 
# investigation without granting any real access to network devices.
#
# The script does not fully emulate the device and its services, and may also crash when scanning, 
# which requires some improvement.
#
# Usage:
# - Deploy the script on a server or device with a web server configured to host the honeypot.
# - python3 honeypot_CSS326-24G-2S+.py --host 0.0.0.0 --port 80 -o /var/log/honeypot_CSS326-24G-2S+.log

import os
import socket
import sys
import base64
import gzip
import logging
import subprocess
from datetime import datetime
import argparse

INDEX_HTML_BASE64_GZIPPED = "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"

def get_mac_address(ip_address):
    try:
        result = subprocess.run(['arp', '-n', ip_address], capture_output=True, text=True)
        for line in result.stdout.split('\n'):
            if ip_address in line:
                return line.split()[2].upper()
    except Exception as e:
        print(f"Error getting MAC address: {e}")
    return "MAC Address Not Found"

def log_auth_attempt(client_ip, mac_address, user_agent, uri, digest_auth):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"{timestamp}, {mac_address}, {client_ip}, {user_agent}, {uri}, {digest_auth}"
    logging.info(log_entry)

def send_http_response(client_socket, content, server_info="MikroTik RouterBoard 250GS httpd"):
    response = f"""HTTP/1.0 200 OK\r
Content-Type: text/html\r
Server: {server_info}\r
\r\n{content}"""
    client_socket.sendall(response.encode('utf-8'))

def send_403_response(client_socket):
    response = """HTTP/1.0 403 Forbidden\r
Content-Type: text/html\r
\r
<html><body><h1>403 Forbidden</h1></body></html>"""
    client_socket.sendall(response.encode('utf-8'))

def send_405_response(client_socket):
    response = """HTTP/1.0 405 Method Not Allowed\r
Allow: GET, POST\r
Content-Type: text/html\r
\r
<html><body><h1>405 Method Not Allowed</h1></body></html>"""
    client_socket.sendall(response.encode('utf-8'))

def start_server(host, port):
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((host, port))
    server_socket.listen(5)
    print(f"Server started on {host}:{port}")

    while True:
        client_socket, client_address = server_socket.accept()
        try:
            request = client_socket.recv(1024)
            try:
                decoded_request = request.decode('utf-8').strip()
                print(f"Request from {client_address}:\n{decoded_request}")
            except UnicodeDecodeError:
                print(f"Received non-UTF-8 request from {client_address}")
                client_socket.close()
                continue

        except Exception as e:
            print(f"Error receiving data: {e}")
            client_socket.close()
            continue

        if not decoded_request:
            print("Received an empty request")
            client_socket.close()
            continue

        request_lines = decoded_request.split("\r\n")
        first_line = request_lines[0].split()

        if len(first_line) < 2:
            print("Malformed request line:", request_lines[0])
            client_socket.close()
            continue

        method, request_path = first_line[0], first_line[1]

        if method in ['HEAD', 'OPTIONS']:
            send_405_response(client_socket)
            client_socket.close()
            continue

        if method not in ['GET', 'POST']:
            send_405_response(client_socket)
            client_socket.close()
            continue

        user_agent = "User-Agent Not Found"
        for line in request_lines:
            if line.startswith("User-Agent:"):
                user_agent = line.split("User-Agent: ")[1]
                break

        digest_auth = "No Authorization Header"
        for line in request_lines:
            if line.startswith("Authorization:"):
                digest_auth = line
                break

        mac_address = get_mac_address(client_address[0])
        log_auth_attempt(client_address[0], mac_address, user_agent, request_path, digest_auth)

        if request_path == '/sys.b':
            response = """HTTP/1.0 401 Unauthorized\r
WWW-Authenticate: Digest realm="CSS326-24G-2S+", qop="auth", nonce="b367c9dc", stale=FALSE\r
Content-Type: text/html\r
\r
<h1>401 Unauthorized</h1>"""
            client_socket.sendall(response.encode('utf-8'))
        elif request_path == '/index.html':
            try:
                gzipped_content = base64.b64decode(INDEX_HTML_BASE64_GZIPPED)
                decompressed_content = gzip.decompress(gzipped_content).decode('utf-8')
                send_http_response(client_socket, decompressed_content, server_info="MikroTik RouterBoard 250GS httpd")
            except Exception as e:
                print(f"Error serving index.html: {e}")
                response = """HTTP/1.0 500 Internal Server Error\r
Content-Type: text/html\r
\r
<html><body><h1>500 Internal Server Error</h1></body></html>"""
                client_socket.sendall(response.encode('utf-8'))
        else:
            response = """HTTP/1.0 302 Found\r
Location: /index.html\r
Content-Type: text/html\r
\r
<html><body><h1>302 Found</h1></body></html>"""
            client_socket.sendall(response.encode('utf-8'))

        client_socket.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Honeypot server')
    parser.add_argument('--host', default='0.0.0.0', help='Host IP to bind the server (default: 0.0.0.0)')
    parser.add_argument('--port', type=int, default=80, help='Port to bind the server (default: 80)')
    parser.add_argument('-o', '--logfile', default=os.path.join(os.getcwd(), 'auth_log.txt'), 
                        help='Path to the log file (default: ./auth_log.txt)')
    
    args = parser.parse_args()

    logging.basicConfig(filename=args.logfile, level=logging.INFO, format='%(asctime)s - %(message)s')

    start_server(args.host, args.port)
