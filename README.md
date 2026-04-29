# Bhumi Finance 🌾
### *Digitizing the Informal Economy: A Daily Micro-Loan Management Suite*

<div align="center">
  <img src="https://github.com/user-attachments/assets/ed8ef977-0dac-4d08-afd5-5f19aa54f2e3" width="250" alt="Bhumi Finance Mobile View">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/3a765424-8759-4366-93b3-360ef06f80ec" width="500" alt="Bhumi Finance Desktop View">
</div>

<br>

**Bhumi Finance** is a purpose-built financial tool designed for local lenders who provide micro-loans to the working class, including daily-wage laborers and small-scale workers. While standard banking apps focus on monthly cycles, Bhumi Finance is engineered for the "Daily Collection" reality of the street-level economy. 

Built as a **true cross-platform solution**, it functions seamlessly as a portable **Mobile App** for field collections and a robust **Desktop Application** for end-of-day ledger management.

---

## 🛠️ Tech Stack & Architecture
* **Frontend:** Flutter (Dart) for high-speed, cross-platform UI across mobile and desktop.
* **Database:** SQLite via `sqflite_common_ffi` for robust local storage on Windows and standard SQLite for mobile environments.
* **Architecture:** Modular Folder System (Themes, Screens, Database, Logic) for scalability and clean code.
* **Theme Management:** `ValueNotifier` for real-time Light/Dark mode switching without performance drops.

---

## 🧠 Challenges & Problem Solving
Building a financial tool as a student required solving real-world engineering problems. Here is how I tackled them:

> ### 1. The Monolith to Modular Transition 🏗️
> **Problem:** Initially, the codebase was a single, massive file that was impossible to debug or scale.  
> **Solution:** I refactored the entire app into a modular structure, separating the UI screens from the database logic and theme configurations. This made the project professional and "Evaluation Ready".

> ### 2. The Desktop Database Hurdle 🖥️
> **Problem:** Standard Flutter SQLite packages are built for mobile, but I needed a reliable solution for Windows/Desktop development alongside the mobile app.  
> **Solution:** I implemented `sqflite_common_ffi` and custom database factory logic to ensure the app runs flawlessly on PC environments while maintaining mobile compatibility.

> ### 3. Daily vs. Monthly Math Logic 📉
> **Problem:** Most banking logic uses monthly interest math, which doesn't work for microfinance daily collections.  
> **Solution:** I developed a custom calculation engine that prioritizes daily collection tracking and ledger visualization specifically tailored for micro-scale operations.

---

## 💻 Installation & Setup

### Prerequisites
* **Flutter SDK** (Stable Channel)
* **Dart SDK**
* For Windows/Linux Desktop deployment: Visual Studio or appropriate C++ build tools

### Setup Instructions
1. **Clone the repository:**
   ```bash
   git clone [https://github.com/YOUR_USERNAME/Bhumi-Finance.git](https://github.com/YOUR_USERNAME/Bhumi-Finance.git)
2. **Navigate to the directory and install dependencies:**
   ```bash
   cd Bhumi-Finance
   flutter pub get
3. Run the Application:
   ```bash
   flutter run
