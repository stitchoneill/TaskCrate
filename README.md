Task Crate – Inventory & Job Planning System

A Java web app for managing inventory items and job tracking. Built with Servlets + JSP and JDBC. Runs on Apache Tomcat 9.x (uses javax.*).

Why Tomcat 9.x?
This project uses the classic javax.servlet.* API. Tomcat 10+ moved to jakarta.*. If you use Tomcat 10+, you must refactor imports to jakarta.*. To keep things simple, use Tomcat 9.x.

Features

Add, edit, delete inventory items

Create jobs using existing items

Inventory quantities auto-update

JDBC persistence (PostgreSQL or SQLite)

Project Structure
/source/                  # Java source (Servlets, DAOs, models)
/WebContent/              # JSPs, static assets
  /WEB-INF/
    /classes/             # (compiled .class files end up here)
    /lib/                 # JDBC drivers go here (sqlite-jdbc, postgresql)
    web.xml               # servlet mappings, context params

Prerequisites

Java 8+ JDK
Ensure JAVA_HOME is set and javac is on PATH.

Apache Tomcat 9.x

Example: C:\apache-tomcat-9.x\

Set CATALINA_HOME to your Tomcat folder.

Servlet API for compilation

You do not bundle this in WEB-INF/lib (Tomcat provides it at runtime).

For compiling, reference:
"%CATALINA_HOME%\lib\servlet-api.jar" (or javax.servlet-api-4.0.1.jar)

Database (choose one):

SQLite (easiest local run)

Add driver JAR to WebContent/WEB-INF/lib/, e.g. sqlite-jdbc-<version>.jar (Xerial).

PostgreSQL (original project)

Run a local Postgres 13+

Add postgresql-42.x.x.jar to WebContent/WEB-INF/lib/.

Database Configuration

You can switch between SQLite and PostgreSQL via JDBC URL and DAO config.

Option A — SQLite (single file DB)

Driver class: org.sqlite.JDBC

JDBC URL (example):
jdbc:sqlite:${CATALINA_BASE}/webapps/InventoryApp/WEB-INF/data/taskcrate.db

Create the folder WebContent/WEB-INF/data/ for the DB file (the app can create/populate on first run if coded to do so). If your DAO expects tables, run the schema below once.

Option B — PostgreSQL

Driver class: org.postgresql.Driver

JDBC URL (example):
jdbc:postgresql://localhost:5432/taskcrate

User/Pass: set as per your local DB.

Suggested web.xml context params

(Adjust names to match your DAO’s config loader if you have a Config utility.)

<context-param>
  <param-name>jdbc.driver</param-name>
  <!-- For SQLite -->
  <param-value>org.sqlite.JDBC</param-value>
  <!-- For Postgres use: org.postgresql.Driver -->
</context-param>

<context-param>
  <param-name>jdbc.url</param-name>
  <!-- SQLite example -->
  <param-value>jdbc:sqlite:${catalina.base}/webapps/InventoryApp/WEB-INF/data/taskcrate.db</param-value>
  <!-- Postgres example: jdbc:postgresql://localhost:5432/taskcrate -->
</context-param>

<context-param>
  <param-name>jdbc.user</param-name>
  <param-value>postgres</param-value>
</context-param>

<context-param>
  <param-name>jdbc.password</param-name>
  <param-value>postgres</param-value>
</context-param>


If your DAOs read from a config.properties instead, mirror the same values there.

Initial Schema (minimal example)

If your app doesn’t auto-migrate, run the SQL once.

Items

CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,  -- SQLite
  -- For Postgres use: SERIAL PRIMARY KEY
  name TEXT NOT NULL,
  sku TEXT UNIQUE,
  quantity INTEGER NOT NULL DEFAULT 0
);


Jobs

CREATE TABLE IF NOT EXISTS jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Postgres: SERIAL PRIMARY KEY
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


For PostgreSQL, swap INTEGER PRIMARY KEY AUTOINCREMENT with SERIAL PRIMARY KEY, and TEXT with suitable VARCHAR lengths if you prefer.

Build & Deploy (Windows)

A ready-to-run deploy.bat is included below. It compiles sources, copies resources, packages a WAR, and drops it in Tomcat’s webapps. It supports both SQLite and PostgreSQL by leaving both JDBC drivers in WEB-INF/lib/ (you’ll just use the one your config points to).

1) Place JDBC driver JARs

Put exactly these into WebContent/WEB-INF/lib/:

sqlite-jdbc-<version>.jar (for SQLite)

postgresql-42.x.x.jar (for PostgreSQL)

2) Add this deploy.bat to project root
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
REM Build classpath: servlet-api (for compile) + JDBC drivers in WEB-INF/lib
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

3) Run it

Open Developer Command Prompt (so javac works)

deploy.bat

Tomcat will auto-expand the WAR into /webapps/InventoryApp/.
Default URL: http://localhost:8080/InventoryApp/
(If you’ve changed Tomcat’s port, adjust accordingly.)

Notes & Troubleshooting

Tomcat 10+ 404 / class not found?
You’re likely on Tomcat 10+ (Jakarta). Use Tomcat 9.x OR migrate imports from javax.* → jakarta.*.

ClassNotFoundException: org.sqlite.JDBC or org.postgresql.Driver
Ensure the JDBC driver JAR is inside WebContent/WEB-INF/lib/ before you run deploy.bat.

Compilation fails: cannot find symbol javax.servlet.*
Check CATALINA_HOME and that %CATALINA_HOME%\lib\servlet-api.jar exists. The batch script compiles against it.

DB path (SQLite)
If you use the ${catalina.base} path in web.xml, Tomcat resolves it at runtime to something like
C:\apache-tomcat-9.x → ...\webapps\InventoryApp\WEB-INF\data\taskcrate.db.
Ensure the data folder exists or your code can create it.

PostgreSQL connectivity
Confirm DB, user, password exist, and your JDBC URL is correct. If running on a non-default port, set it in the URL.

Setup Quickstart (TL;DR)

Install JDK 8+ and Tomcat 9.x.

Set JAVA_HOME and CATALINA_HOME.

Drop JDBC driver JAR(s) into WebContent/WEB-INF/lib/.

Configure DB via web.xml (SQLite or Postgres).

Run deploy.bat.

Browse to http://localhost:8080/InventoryApp/.

Author

Liam O’Neill