from flask import Flask, render_template, request, redirect, url_for, flash
import markdown2
import os
import re
import subprocess
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'supersecretkey'  # Required for flash messages

# Path to save files
SAVE_DIR = 'saved_data'

if not os.path.exists(SAVE_DIR):
    os.makedirs(SAVE_DIR)

def validate_name(name):
    """ Validation of the name: only lowercase Latin characters up to 50 characters """
    if re.match("^[a-z]{1,50}$", name):
        return True
    return False

def get_mac_address(ip_address):
    """ Retrieves the MAC address of the device using the given IP address """
    try:
        # Run the arp command to get the MAC address
        result = subprocess.run(['arp', '-n', ip_address], capture_output=True, text=True)
        # Parse the result of the command
        for line in result.stdout.split('\n'):
            if ip_address in line:
                return line.split()[3].upper()
    except Exception as e:
        print(f"Error getting MAC address: {e}")
    return "MAC Address Not Found"

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        name = request.form.get('name')
        markdown_text = request.form.get('markdown_text')

        # Name validation
        if not validate_name(name):
            flash('Name must consist of lowercase Latin letters (up to 50 characters)')
            return render_template('index.html', name=name, markdown_text=markdown_text, html_preview='')

        # Get User Agent, IP, MAC, and current time
        user_agent = request.headers.get('User-Agent')
        user_ip = request.remote_addr
        user_mac = get_mac_address(user_ip)  # Get the MAC address based on IP
        current_time = datetime.now().strftime('%d.%m.%Y %H:%M:%S')

        # Add metadata at the beginning of the text
        metadata = f"**User Agent**: {user_agent}\n**IP**: {user_ip}\n**MAC Address**: {user_mac}\n**Time**: {current_time}\n\n"
        full_markdown_text = metadata + markdown_text

        # Generate Markdown to HTML for preview
        html_preview = markdown2.markdown(full_markdown_text, extras=["fenced-code-blocks"])

        # If 'SAVE' button is pressed
        if 'save' in request.form:
            # Generate timestamp for the file suffix
            file_suffix_time = datetime.now().strftime('%d%m%Y_%H%M%S')
            file_name = f"{name}@gmail.com_{file_suffix_time}.md"
            file_path = os.path.join(SAVE_DIR, file_name)

            # Save the file
            with open(file_path, 'w') as f:
                f.write(full_markdown_text)
            return redirect(url_for('saved', filename=file_name))

        return render_template('index.html', name=name, markdown_text=markdown_text, html_preview=html_preview)

    return render_template('index.html', name='', markdown_text='', html_preview='')

@app.route('/saved/<filename>')
def saved(filename):
    return f"File saved as {filename}"

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=80)
