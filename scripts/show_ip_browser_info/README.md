# Client Information and Logging Flask App

This Flask application is designed to capture and display information about clients who make requests to the server. It provides an overview of the client's IP address, User Agent, and request headers, while also maintaining a log of all requests made to the server.

## Features

- **Client Information Display**: The application captures the client's IP address, User Agent, and all request headers for each incoming request.
- **Request Logging**: Each request is logged with the client's IP address, the accessed path, and the User Agent, allowing for easy tracking of all interactions with the server.
- **Dynamic Route Handling**: The application handles requests to the root route (`/`) and any other path, providing consistent information and logging for all endpoints.
- **Real-time Logs**: A list of all past requests is displayed on the page, offering a real-time view of the server's activity.

## How to Run

1. **Set up a virtual environment**:
   - Create a virtual environment:
     ```bash
     python3 -m venv venv
     ```
   - Activate the virtual environment:
     ```bash
     source venv/bin/activate
     ```

2. **Install dependencies**:
   - With the virtual environment activated, install Flask:
     ```bash
     pip install flask
     ```

3. **Run the application**:
   - Start the Flask server:
     ```bash
     python ./scripts/show_ip_browser_info/app.py
     ```

4. **Access the application**:
   - Open your browser and navigate to `http://localhost:5000/` to see the client information and logs.

5. **Deactivate the virtual environment** (optional):
   - After you're done, deactivate the virtual environment:
     ```bash
     deactivate
     ```
