from flask import Flask, request, render_template_string

app = Flask(__name__)

logs = []

@app.route('/')
def index():
    user_ip = request.remote_addr
    user_agent = request.headers.get('User-Agent')
    user_info = {
        'IP Address': user_ip,
        'User Agent': user_agent,
        'Headers': dict(request.headers)
    }
    
    logs.append({'IP': user_ip, 'Path': request.path, 'User Agent': user_agent})
    
    return render_template_string('''
        <h1>Client Information</h1>
        <p><strong>IP Address:</strong> {{ user_info['IP Address'] }}</p>
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
    user_info = {
        'IP Address': user_ip,
        'User Agent': user_agent,
        'Headers': dict(request.headers)
    }
    
    logs.append({'IP': user_ip, 'Path': request.path, 'User Agent': user_agent})
    
    return render_template_string('''
        <h1>Client Information</h1>
        <p><strong>IP Address:</strong> {{ user_info['IP Address'] }}</p>
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
                <strong>IP:</strong> {{ log['IP'] }} 
                <strong>Path:</strong> {{ log['Path'] }} 
                <strong>User Agent:</strong> {{ log['User Agent'] }}
            </li>
        {% endfor %}
        </ul>
    ''', user_info=user_info, logs=logs)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
