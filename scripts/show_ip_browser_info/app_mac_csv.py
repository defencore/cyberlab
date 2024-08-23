from flask import Flask, request, render_template_string
import csv
import os
import subprocess

app = Flask(__name__)

logs = []

def get_mac_address(ip_address):
    try:
        # Виконуємо команду arp для отримання MAC адреси
        result = subprocess.run(['arp', '-n', ip_address], capture_output=True, text=True)
        # Парсимо результат команди
        for line in result.stdout.split('\n'):
            if ip_address in line:
                return line.split()[3].upper()
    except Exception as e:
        print(f"Error getting MAC address: {e}")
    return "MAC Address Not Found"

def save_logs_to_csv(logs):
    file_exists = os.path.isfile('logs.csv')
    with open('logs.csv', mode='a', newline='') as file:
        writer = csv.writer(file)
        if not file_exists:
            writer.writerow(['MAC', 'IP', 'Path', 'User Agent'])
        for log in logs:
            writer.writerow([log['MAC'], log['IP'], log['Path'], log['User Agent']])

@app.route('/')
def index():
    user_ip = request.remote_addr
    user_agent = request.headers.get('User-Agent')
    mac_address = get_mac_address(user_ip)
    user_info = {
        'IP Address': user_ip,
        'User Agent': user_agent,
        'MAC': mac_address,
        'Headers': dict(request.headers)
    }
    
    logs.append({'MAC': mac_address, 'IP': user_ip, 'Path': request.path, 'User Agent': user_agent})
    save_logs_to_csv(logs)
    
    return render_template_string('''
        <h1>Client Information</h1>
        <p><strong>IP Address:</strong> {{ user_info['IP Address'] }}</p>
        <p><strong>MAC:</strong> {{ user_info['MAC'] }}</p>
        <p><strong>User Agent:</strong> {{ user_info['User Agent'] }}</p>
       
        <h2>Headers</h2>
        <ul>
        {% for key, value in user_info['Headers'].items() %}
            <li><strong>{{ key }}:</strong> {{ value }}</li>
        {% endfor %}
        </ul>
        <h2>Logs</h2>
        <ul>
        {% for log in logs %}
            <li>
                <strong>MAC:</strong> {{ log['MAC'] }} 
                <strong>IP:</strong> {{ log['IP'] }} 
                <strong>Path:</strong> {{ log['Path'] }} 
                <strong>User Agent:</strong> {{ log['User Agent'] }}
            </li>
        {% endfor %}
        </ul>
    ''', user_info=user_info, logs=logs)

@app.route('/<path:path>')
def catch_all(path):
    user_ip = request.remote_addr
    user_agent = request.headers.get('User-Agent')
    mac_address = get_mac_address(user_ip)
    user_info = {
        'IP Address': user_ip,
        'User Agent': user_agent,
        'MAC': mac_address,
        'Headers': dict(request.headers)
    }
    
    logs.append({'MAC': mac_address, 'IP': user_ip, 'Path': request.path, 'User Agent': user_agent})
    save_logs_to_csv(logs)
    
    return render_template_string('''
        <h1>Client Information</h1>
        <p><strong>IP Address:</strong> {{ user_info['IP Address'] }}</p>
        <p><strong>User Agent:</strong> {{ user_info['User Agent'] }}</p>
        <p><strong>MAC:</strong> {{ user_info['MAC'] }}</p>
        <h2>Headers</h2>
        <ul>
        {% for key, value in user_info['Headers'].items() %}
            <li><strong>{{ key }}:</strong> {{ value }}</li>
        {% endfor %}
        </ul>
        <h2>Logs</h2>
        <ul>
        {% for log in logs %}
            <li>
                <strong>MAC:</strong> {{ log['MAC'] }} 
                <strong>IP:</strong> {{ log['IP'] }} 
                <strong>Path:</strong> {{ log['Path'] }} 
                <strong>User Agent:</strong> {{ log['User Agent'] }}
            </li>
        {% endfor %}
        </ul>
    ''', user_info=user_info, logs=logs)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
