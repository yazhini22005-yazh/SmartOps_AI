# SmartOps AI – Intelligent Inventory & Operations Management System

## 📌 Project Overview

**SmartOps AI** is an AI-assisted inventory and operations management system designed to help businesses monitor stock levels, identify inventory risks, and manage operational activities efficiently.

The application combines a Python backend with a Flutter frontend to provide inventory insights, operational dashboards, and voice-assisted interactions.

The goal of this project is to simplify inventory monitoring, improve decision-making, and reduce manual effort through intelligent insights and automation.

## 🎯 Objectives

* Monitor inventory and stock levels efficiently.
* Identify potential stockout risks.
* Provide inventory insights through an AI-assisted dashboard.
* Simplify operational workflows.
* Improve accessibility through voice-assisted interactions.
* Integrate a Flutter frontend with a Python backend API.

## ✨ Key Features

### 📦 Inventory Management

* Monitor inventory information.
* View stock-related details.
* Support inventory operations through the application.

### 🤖 AI-Based Stockout Risk Analysis

* Analyze current inventory data.
* Identify potential stockout risks.
* Generate rule-based inventory risk insights.
* Support better inventory planning and decision-making.

> Note: The current stockout risk analysis is rule-based and does not use a trained machine learning model.

### 📊 Management Dashboard

* View important operational information.
* Access inventory-related insights.
* Monitor stock risk information.

### 🗣️ Voice-Assisted AI Assistant

* Interact with the application using voice-related functionality.
* Support voice-based user interactions.
* Improve ease of use for operational workflows.

### 🔗 Backend API Integration

* Connect the Flutter application to the Python backend.
* Retrieve inventory-related information through API endpoints.
* Support communication between the frontend and backend.

## 🛠️ Technologies Used

### Frontend

* Flutter
* Dart

### Backend

* Python
* FastAPI
* SQLAlchemy

### Database

* SQLite

### Development Tools

* Visual Studio Code
* Git
* GitHub
* Postman (for API testing, if used)

## 🏗️ System Architecture

The application follows a frontend-backend architecture.

```text
          User
           |
           v
    Flutter Application
           |
           v
       Backend API
       (FastAPI)
           |
           v
   Business Logic Layer
           |
           v
         SQLite
           |
           v
 Inventory Data & Risk Insights
```

## 🚀 Getting Started

Follow these steps to run the project locally.

### Prerequisites

Install the following tools:

* Python
* Flutter SDK
* Dart SDK (included with Flutter)
* Git

### 1. Clone the Repository

```bash
git clone https://github.com/yazhini22005-yazh/SmartOps_AI.git
```

Navigate to the project directory:

```bash
cd SmartOps_AI
```

### 2. Set Up the Python Backend

Create a virtual environment:

```bash
python -m venv .venv
```

Activate the virtual environment on Windows:

```powershell
.venv\Scripts\Activate.ps1
```

Install the backend dependencies:

```bash
pip install -r requirements.txt
```

> If the `requirements.txt` file is located inside the backend folder, run the installation command from that folder or provide its correct path.

### 3. Run the Backend

Navigate to the directory containing the FastAPI application entry point.

For example, if the application entry point is `main.py`:

```bash
uvicorn main:app --reload
```

If your `main.py` file is inside a `backend` folder, navigate to that folder before running the command.

Once the server starts, open:

```text
http://127.0.0.1:8000
```

If FastAPI Swagger documentation is enabled, access the API documentation at:

```text
http://127.0.0.1:8000/docs
```

### 4. Set Up the Flutter Application

Open a new terminal and navigate to the Flutter application directory.

Run:

```bash
flutter pub get
```

Check the Flutter environment:

```bash
flutter doctor
```

Start the application using:

```bash
flutter run
```

> Make sure the backend is running and the Flutter application's API base URL is configured correctly for your device or emulator.

## 🔍 Example Use Case

A business can use SmartOps AI to monitor its inventory and identify products that may run out of stock.

The backend analyzes the available inventory information and generates rule-based risk insights. These insights can help users identify products that may require replenishment and make informed inventory decisions.

## 🔮 Future Enhancements

* Machine learning-based demand forecasting.
* More advanced stockout prediction models.
* Automated low-stock notifications.
* Inventory analytics and visualization.
* Cloud database integration.
* Role-based authentication and authorization.
* Production deployment of the backend API.
* Enhanced voice interaction capabilities.

## 👨‍💻 Project Information

**Project Name:** SmartOps AI

**Category:** AI-Assisted Inventory Management

**Frontend:** Flutter & Dart

**Backend:** Python & FastAPI

**Database:** SQLite

**Repository:** https://github.com/yazhini22005-yazh/SmartOps_AI

## 📄 License

This project is available for learning and demonstration purposes. Add an appropriate open-source license if you intend to distribute it for reuse.
