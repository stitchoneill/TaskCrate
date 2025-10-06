# 🧩 Task Crate – Inventory & Job Planning System

A **Java web application** for managing inventory items and job tracking.  
Built with **Servlets + JSP** and **JDBC**, and designed to run on **Apache Tomcat 9.x** (uses the `javax.*` API).

---

## ⚙️ Why Tomcat 9.x?

This project uses the **classic `javax.servlet.*` API**.  
Tomcat 10+ switched to **`jakarta.*`**, which would require refactoring imports.

> ✅ To keep things simple, use **Tomcat 9.x**.

---

## ✨ Features

- Add, edit, and delete inventory items  
- Create jobs using existing items  
- Inventory quantities auto-update automatically  
- JDBC persistence (**PostgreSQL** or **SQLite**)

---

## 🗂️ Project Structure

/source/ # Java source (Servlets, DAOs, models)
/WebContent/ # JSPs, static assets
/WEB-INF/
/classes/ # Compiled .class files end up here
/lib/ # JDBC drivers go here (sqlite-jdbc, postgresql)
web.xml # Servlet mappings, context params

---

## 🔧 Prerequisites

### 1. Java 8+ JDK
Ensure `JAVA_HOME` is set and `javac` is on PATH.

### 2. Apache Tomcat 9.x
Example:
C:\apache-tomcat-9.x\

Set the environment variable:
CATALINA_HOME=C:\apache-tomcat-9.x

### 3. Servlet API for Compilation
Do **not** bundle this in `WEB-INF/lib` — Tomcat provides it at runtime.  
For compiling, reference:
%CATALINA_HOME%\lib\servlet-api.jar
(or `javax.servlet-api-4.0.1.jar`)

### 4. Database Driver (choose one)

#### • SQLite (easiest local run)
Add driver JAR to:
WebContent/WEB-INF/lib/

Example: `sqlite-jdbc-<version>.jar` (Xerial)

## 🛠️ Database Configuration

### Option A — SQLite (single-file DB)
- **Driver class:** `org.sqlite.JDBC`  
- **JDBC URL:**
jdbc:sqlite:${CATALINA_BASE}/webapps/InventoryApp/WEB-INF/data/taskcrate.db

- Create the folder:
WebContent/WEB-INF/data/

## 🧾 Suggested `web.xml` Context Params

*(Adjust names to match your DAO’s Config loader.)*

```xml
<context-param>
<param-name>jdbc.driver</param-name>
<param-value>org.sqlite.JDBC</param-value>
</context-param>

<context-param>
<param-name>jdbc.url</param-name>
<param-value>jdbc:sqlite:${catalina.base}/webapps/InventoryApp/WEB-INF/data/taskcrate.db</param-value>
</context-param>

<context-param>
<param-name>jdbc.user</param-name>
<param-value>postgres</param-value>
</context-param>

<context-param>
<param-name>jdbc.password</param-name>
<param-value>postgres</param-value>
</context-param>
If your DAOs read from a config.properties, mirror these values there.

🧮 Initial Schema (Example)
If your app doesn’t auto-migrate, run the SQL below once.

Items
CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,  -- PostgreSQL: SERIAL PRIMARY KEY
  name TEXT NOT NULL,
  sku TEXT UNIQUE,
  quantity INTEGER NOT NULL DEFAULT 0
);

Jobs
sql
CREATE TABLE IF NOT EXISTS jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,  -- PostgreSQL: SERIAL PRIMARY KEY
  title TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

Job Items (many-to-many)
CREATE TABLE IF NOT EXISTS job_items (
  job_id INTEGER NOT NULL,
  item_id INTEGER NOT NULL,
  qty_used INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (job_id, item_id)
);

🚀 Build & Deploy (Windows)
A ready-to-run deploy.bat is included.
It compiles sources, copies resources, packages a WAR, and drops it in Tomcat’s webapps/ directory.

Step 1 — Place JDBC Driver JARs
Put exactly these files into:

WebContent/WEB-INF/lib/
sqlite-jdbc-<version>.jar (for SQLite)

Step 2 — Add this deploy.bat to your project root

@echo off
setlocal enabledelayedexpansion

REM === Edit these if needed ===
set APP_NAME=InventoryApp
set SRC_DIR=source
set WEB_DIR=WebContent
set CLASSES_DIR=%WEB_DIR%\WEB-INF\classes
set LIB_DIR=%WEB_DIR%\WEB-INF\lib

if "%CATALINA_HOME%"=="" (
  echo [ERROR] CATALINA_HOME is not set. Please set it to your Tomcat 9 folder.
  echo Example: set CATALINA_HOME=C:\apache-tomcat-9.0.8x
  exit /b 1
)

if not exist "%CATALINA_HOME%\lib\servlet-api.jar" (
  echo [ERROR] Cannot find servlet-api.jar under %CATALINA_HOME%\lib
  exit /b 1
)

echo.
echo === Cleaning classes ===
if exist "%CLASSES_DIR%" rmdir /s /q "%CLASSES_DIR%"
mkdir "%CLASSES_DIR%"

echo.
echo === Collecting Java sources ===
del /q /f sources.txt 2>nul
for /r "%SRC_DIR%" %%f in (*.java) do (
  echo %%f>> sources.txt
)

if not exist sources.txt (
  echo [ERROR] No Java sources found under %SRC_DIR%
  exit /b 1
)

echo.
echo === Compiling ===
set CP="%CATALINA_HOME%\lib\servlet-api.jar"
for %%j in ("%LIB_DIR%\*.jar") do (
  set CP=!CP!;%%j
)

javac -encoding UTF-8 -cp !CP! -d "%CLASSES_DIR%" @sources.txt
if errorlevel 1 (
  echo [ERROR] Compilation failed.
  exit /b 1
)

echo.
echo === Packaging WAR ===
pushd "%WEB_DIR%"
if exist "%APP_NAME%.war" del /q "%APP_NAME%.war"
jar -cvf "%APP_NAME%.war" *
popd

if not exist "%WEB_DIR%\%APP_NAME%.war" (
  echo [ERROR] WAR not found after packaging.
  exit /b 1
)

echo.
echo === Deploying to Tomcat webapps ===
copy /y "%WEB_DIR%\%APP_NAME%.war" "%CATALINA_HOME%\webapps\%APP_NAME%.war" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy WAR to Tomcat webapps.
  exit /b 1
)

echo.
echo Deployment complete.
echo Start Tomcat (bin\startup.bat) and open: http://localhost:8080/%APP_NAME%/
endlocal
Step 3 — Run It
Open a Developer Command Prompt (so javac works) and run:

Copy code
deploy.bat
Tomcat will automatically expand the WAR into:

bash
Copy code
/webapps/InventoryApp/
Then open:
👉 http://localhost:8080/InventoryApp/
(Adjust if you’ve changed Tomcat’s port.)

🧰 Notes & Troubleshooting
Tomcat 10+ 404 / Class Not Found?
You’re probably using Tomcat 10+. Use Tomcat 9.x or migrate javax.* → jakarta.*.

ClassNotFoundException: org.sqlite.JDBC or org.postgresql.Driver
Ensure the JDBC driver JAR is inside WebContent/WEB-INF/lib/ before running deploy.bat.

Compilation fails: cannot find symbol javax.servlet.*
Check that %CATALINA_HOME%\lib\servlet-api.jar exists.

SQLite DB path
If you use ${catalina.base} in web.xml, Tomcat resolves it at runtime to something like:

kotlin
Copy code
C:\apache-tomcat-9.x\webapps\InventoryApp\WEB-INF\data\taskcrate.db
Ensure the data folder exists or is created automatically.

⚡ Setup Quickstart (TL;DR)
Install JDK 8+ and Tomcat 9.x

Set JAVA_HOME and CATALINA_HOME

Drop JDBC driver JARs into WebContent/WEB-INF/lib/

Configure DB via web.xml

Run deploy.bat

Visit http://localhost:8080/InventoryApp/

👤 Author
Liam O’Neill

