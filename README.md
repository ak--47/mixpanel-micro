# mixpanel-micro 🔬

**a universal, zero-dependency Mixpanel event tracker that works everywhere.**

one shell script. no libraries or dependencies. runs on any platform with a POSIX shell.

## Why?

[Mixpanel SDKs are great](https://docs.mixpanel.com/docs/tracking-methods/sdks), you should totally use them. Don't use this script if you can use an official SDK.

But sometimes you can't use an official SDK because:

- Lambda functions have limited bundle size
- Legacy systems running exotic languages (Perl, Tcl, Lua)
- Embedded devices and IoT hardware
- Docker containers where you want the absolute minimum footprint
- Build scripts, cronjobs, and automation tools that run in bash
- Environments where you can't install dependencies 

**mixpanel-micro** solves this with one file that works everywhere.

## Quick Start

```bash
# download the script
curl -O https://raw.githubusercontent.com/ak--47/mixpanel-micro/refs/heads/main/mixpanel-micro.sh

# allow it to run
chmod +x mixpanel-micro.sh

# Send your first event
./mixpanel-micro.sh "YOUR_TOKEN" "Hello World"
```

That's it.

## Usage

```bash
./mixpanel-micro.sh <TOKEN> <EVENT> [PROPERTIES] [DISTINCT_ID] [FLAGS]
```

### Flags

- `--verbose` - Show the payload and API response
- `--dry-run` - Print payload without sending request (implies --verbose)

### Examples

```bash
# Minimal - auto-generates distinct_id from hostname + user
./mixpanel-micro.sh "YOUR_TOKEN" "Script Started"

# With properties
./mixpanel-micro.sh "YOUR_TOKEN" "File Uploaded" '{"size_mb": 12.5, "type": "pdf"}'

# With distinct_id
./mixpanel-micro.sh "YOUR_TOKEN" "Login" '{"method": "password"}' "user_alice"

# Debug mode
./mixpanel-micro.sh "YOUR_TOKEN" "Test" '{"foo": "bar"}' "test_user" --verbose

# Test without sending
./mixpanel-micro.sh "YOUR_TOKEN" "Test" '{"foo": "bar"}' "test_user" --dry-run
```

---

## Deployment Recipes

### AWS Lambda (Node.js)

Package the script with your Lambda function:

```javascript
// lambda/index.js
const { execFile } = require('child_process');
const path = require('path');

const track = (event, props = {}) => {
  execFile(
    path.join(__dirname, 'mixpanel-micro.sh'),
    [process.env.MIXPANEL_TOKEN, event, JSON.stringify(props), 'lambda'],
    (err) => { if (err) console.error(err); }
  );
};

exports.handler = async (event) => {
  track('Lambda Invoked', {
    runtime: process.version,
    memory: process.env.AWS_LAMBDA_FUNCTION_MEMORY_SIZE
  });

  // Your Lambda logic here
  return { statusCode: 200, body: 'OK' };
};
```


### AWS Lambda (Python)

```python
# lambda_function.py
import subprocess
import json
import os

def track(event, props={}):
    subprocess.Popen([
        './mixpanel-micro.sh',
        os.environ['MIXPANEL_TOKEN'],
        event,
        json.dumps(props),
        'lambda'
    ])

def lambda_handler(event, context):
    track('Lambda Invoked', {
        'runtime': 'python3.9',
        'memory': os.environ.get('AWS_LAMBDA_FUNCTION_MEMORY_SIZE')
    })

    return {'statusCode': 200, 'body': 'OK'}
```

### Docker Container

Add one line to your Dockerfile:

```dockerfile
FROM alpine:latest

# Your existing setup...
RUN apk add --no-cache curl

# Add mixpanel-micro
COPY mixpanel-micro.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/mixpanel-micro.sh

# Track container starts
CMD mixpanel-micro.sh "$MIXPANEL_TOKEN" "Container Started" "{\"image\": \"$IMAGE_TAG\"}" && \
    exec your-actual-command
```

**Minimal Alpine example:**
```dockerfile
FROM alpine:3.18
RUN apk add --no-cache curl
COPY mixpanel-micro.sh /app/
WORKDIR /app
CMD ./mixpanel-micro.sh "$TOKEN" "Alpine Started" && sleep 3600
```

### Kubernetes CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: analytics-job
spec:
  schedule: "0 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: job
            image: alpine:latest
            command:
            - /bin/sh
            - -c
            - |
              apk add --no-cache curl
              curl -O https://raw.githubusercontent.com/ak--47/mixpanel-micro/main/mixpanel-micro.sh
              chmod +x mixpanel-micro.sh
              ./mixpanel-micro.sh "$MIXPANEL_TOKEN" "K8s Job" '{"cluster": "production"}'
              # Your actual job logic here
            env:
            - name: MIXPANEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: mixpanel-secret
                  key: token
          restartPolicy: OnFailure
```

### GitHub Actions

```yaml
# .github/workflows/analytics.yml
name: Build with Analytics
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Analytics
        run: |
          curl -O https://raw.githubusercontent.com/ak--47/mixpanel-micro/main/mixpanel-micro.sh
          chmod +x mixpanel-micro.sh

      - name: Track Build Start
        run: |
          ./mixpanel-micro.sh "${{ secrets.MIXPANEL_TOKEN }}" "Build Started" \
            '{"repo": "${{ github.repository }}", "branch": "${{ github.ref_name }}"}'

      - name: Run Tests
        run: npm test

      - name: Track Build Complete
        if: success()
        run: |
          ./mixpanel-micro.sh "${{ secrets.MIXPANEL_TOKEN }}" "Build Success" \
            '{"repo": "${{ github.repository }}"}'
```

### Raspberry Pi / IoT

```bash
# /home/pi/sensor.sh
#!/bin/bash

# One-time setup
if [ ! -f ~/mixpanel-micro.sh ]; then
  curl -o ~/mixpanel-micro.sh https://raw.githubusercontent.com/ak--47/mixpanel-micro/main/mixpanel-micro.sh
  chmod +x ~/mixpanel-micro.sh
fi

TOKEN="YOUR_TOKEN"
DEVICE_ID="pi-$(hostname)"

# Read temperature sensor
TEMP=$(vcgencmd measure_temp | grep -o '[0-9.]*')

# Track it
~/mixpanel-micro.sh "$TOKEN" "Temperature Reading" \
  "{\"temp_c\": $TEMP, \"device\": \"$DEVICE_ID\"}" "$DEVICE_ID"
```


### Vercel/Netlify Edge Functions

```javascript
// api/hello.js
import { exec } from 'child_process';
import { promisify } from 'util';
const execAsync = promisify(exec);

export default async function handler(req, res) {
  // Fire and forget
  execAsync(`./mixpanel-micro.sh "${process.env.MIXPANEL_TOKEN}" "Edge Function" '{"region": "sfo1"}'`);

  return res.status(200).json({ message: 'Hello from the edge!' });
}
```

### Git Hooks

Track commits, pushes, and other Git events:

```bash
# .git/hooks/post-commit
#!/bin/bash

# Get commit info
AUTHOR=$(git log -1 --format='%an')
MESSAGE=$(git log -1 --format='%s' | head -c 50)
HASH=$(git log -1 --format='%h')

# Track commit
./mixpanel-micro.sh "YOUR_TOKEN" "Git Commit" \
  "{\"author\": \"$AUTHOR\", \"hash\": \"$HASH\"}" "$AUTHOR"
```

### systemd Service

Track service starts/stops/failures:

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target

[Service]
Type=simple
ExecStartPre=/usr/local/bin/mixpanel-micro.sh "$TOKEN" "Service Starting" '{"host": "%H"}'
ExecStart=/usr/local/bin/myapp
ExecStopPost=/usr/local/bin/mixpanel-micro.sh "$TOKEN" "Service Stopped" '{"host": "%H"}'

[Install]
WantedBy=multi-user.target
```

### Nginx / OpenResty (Lua)

```lua
-- /etc/nginx/lua/analytics.lua
local http = require "resty.http"
local cjson = require "cjson"

local function track(event, props)
    local handle = io.popen(string.format(
        "/usr/local/bin/mixpanel-micro.sh '%s' '%s' '%s' '%s'",
        os.getenv("MIXPANEL_TOKEN"),
        event,
        cjson.encode(props),
        ngx.var.remote_addr
    ))
    handle:close()
end

-- Track in nginx.conf
-- access_by_lua_block {
--   require("analytics").track("Page View", {path = ngx.var.uri})
-- }
```

---

## Language Examples

The pattern: Create a tracker factory that captures `token` and `distinct_id`, returning a lightweight `track()` function.

### Node.js / TypeScript

```javascript
const { execFile } = require('child_process');
const path = require('path');

function createTracker(token, distinctId) {
  const scriptPath = path.join(__dirname, 'mixpanel-micro.sh');
  return (event, props = {}) => {
    execFile(scriptPath, [token, event, JSON.stringify(props), distinctId],
      (err) => { if (err) console.error(err); }
    );
  };
}

// Hello World
const track = createTracker('YOUR_TOKEN', 'user_123');
track('Hello World', { timestamp: Date.now() });
```

### Python

```python
import subprocess
import json

def create_tracker(token, distinct_id):
    def track(event_name, props={}):
        subprocess.Popen(
            ['./mixpanel-micro.sh', token, event_name, json.dumps(props), distinct_id],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    return track

# Hello World
track = create_tracker("YOUR_TOKEN", "alice@example.com")
track("Hello World", {"timestamp": "2024-01-15"})
```

### Go

```go
package main

import (
    "encoding/json"
    "os/exec"
)

type Tracker struct {
    Token, DistinctID, ScriptPath string
}

func NewTracker(token, distinctID string) *Tracker {
    return &Tracker{token, distinctID, "./mixpanel-micro.sh"}
}

func (t *Tracker) Track(event string, props map[string]interface{}) {
    propsBytes, _ := json.Marshal(props)
    exec.Command(t.ScriptPath, t.Token, event, string(propsBytes), t.DistinctID).Start()
}

// Hello World
func main() {
    mp := NewTracker("YOUR_TOKEN", "device_42")
    mp.Track("Hello World", map[string]interface{}{"language": "go"})
}
```

### Ruby

```ruby
require 'json'

class MixpanelMicro
  def initialize(token, distinct_id)
    @token, @distinct_id = token, distinct_id
  end

  def track(event, props = {})
    pid = spawn("./mixpanel-micro.sh", @token, event, props.to_json, @distinct_id)
    Process.detach(pid)
  end
end

# Hello World
mp = MixpanelMicro.new("YOUR_TOKEN", "user_ruby")
mp.track("Hello World", { language: "ruby" })
```

### PHP

```php
<?php
function track($event, $props = []) {
    $cmd = sprintf(
        './mixpanel-micro.sh %s %s %s %s > /dev/null 2>&1 &',
        escapeshellarg(getenv('MIXPANEL_TOKEN')),
        escapeshellarg($event),
        escapeshellarg(json_encode($props)),
        escapeshellarg('php_user')
    );
    exec($cmd);
}

// Hello World
track("Hello World", ["language" => "php"]);
```

### Rust

```rust
use std::process::Command;

struct Tracker { token: String, distinct_id: String }

impl Tracker {
    fn new(token: &str, distinct_id: &str) -> Self {
        Tracker {
            token: token.to_string(),
            distinct_id: distinct_id.to_string()
        }
    }

    fn track(&self, event: &str, props_json: &str) {
        Command::new("./mixpanel-micro.sh")
            .args(&[&self.token, event, props_json, &self.distinct_id])
            .spawn()
            .expect("failed to track");
    }
}

// Hello World
fn main() {
    let t = Tracker::new("YOUR_TOKEN", "rust_user");
    t.track("Hello World", r#"{"language": "rust"}"#);
}
```

### Java

```java
import java.io.IOException;

public class Analytics {
    private final String token, userId;

    public Analytics(String token, String userId) {
        this.token = token;
        this.userId = userId;
    }

    public void track(String event, String jsonProps) {
        try {
            new ProcessBuilder("./mixpanel-micro.sh", token, event, jsonProps, userId).start();
        } catch (IOException e) { e.printStackTrace(); }
    }

    // Hello World
    public static void main(String[] args) {
        Analytics mp = new Analytics("YOUR_TOKEN", "java_user");
        mp.track("Hello World", "{\"language\": \"java\"}");
    }
}
```

### C

```c
#include <stdlib.h>
#include <stdio.h>

void track(const char* token, const char* event, const char* props, const char* user_id) {
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
        "./mixpanel-micro.sh '%s' '%s' '%s' '%s' &",
        token, event, props, user_id);
    system(cmd);
}

// Hello World
int main() {
    track("YOUR_TOKEN", "Hello World", "{\"language\": \"c\"}", "c_user");
    return 0;
}
```

### C++

```cpp
#include <cstdlib>
#include <string>
#include <sstream>

class Tracker {
    std::string token, distinct_id;
public:
    Tracker(const std::string& t, const std::string& id) : token(t), distinct_id(id) {}

    void track(const std::string& event, const std::string& props = "{}") {
        std::ostringstream cmd;
        cmd << "./mixpanel-micro.sh '" << token << "' '" << event
            << "' '" << props << "' '" << distinct_id << "' &";
        std::system(cmd.str().c_str());
    }
};

// Hello World
int main() {
    Tracker mp("YOUR_TOKEN", "cpp_user");
    mp.track("Hello World", R"({"language": "cpp"})");
    return 0;
}
```

### Swift

```swift
import Foundation

class Tracker {
    let token: String
    let distinctId: String

    init(token: String, distinctId: String) {
        self.token = token
        self.distinctId = distinctId
    }

    func track(event: String, props: [String: Any] = [:]) {
        let propsJson = try? JSONSerialization.data(withJSONObject: props)
        let propsString = propsJson.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "./mixpanel-micro.sh")
        task.arguments = [token, event, propsString, distinctId]
        try? task.run()
    }
}

// Hello World
let mp = Tracker(token: "YOUR_TOKEN", distinctId: "swift_user")
mp.track(event: "Hello World", props: ["language": "swift"])
```

### Elixir

```elixir
defmodule MixpanelMicro do
  def track(event, props \\ %{}, distinct_id \\ "elixir_user") do
    token = System.get_env("MIXPANEL_TOKEN")
    props_json = Jason.encode!(props)

    System.cmd("./mixpanel-micro.sh", [token, event, props_json, distinct_id])
  end
end

# Hello World
MixpanelMicro.track("Hello World", %{language: "elixir"})
```

### Scala

```scala
import scala.sys.process._
import spray.json._

object Analytics {
  def track(token: String, event: String, props: JsObject, userId: String): Unit = {
    Seq("./mixpanel-micro.sh", token, event, props.compactPrint, userId).!
  }
}

// Hello World
Analytics.track("YOUR_TOKEN", "Hello World",
  JsObject("language" -> JsString("scala")), "scala_user")
```

### Kotlin

```kotlin
import java.io.IOException

class Tracker(private val token: String, private val userId: String) {
    fun track(event: String, propsJson: String = "{}") {
        try {
            ProcessBuilder("./mixpanel-micro.sh", token, event, propsJson, userId).start()
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }
}

// Hello World
fun main() {
    val mp = Tracker("YOUR_TOKEN", "kotlin_user")
    mp.track("Hello World", """{"language": "kotlin"}""")
}
```

### R

```r
track <- function(event, props = list(), distinct_id = "r_user") {
  token <- Sys.getenv("MIXPANEL_TOKEN")
  props_json <- jsonlite::toJSON(props, auto_unbox = TRUE)

  system2("./mixpanel-micro.sh",
          args = c(token, event, props_json, distinct_id),
          wait = FALSE)
}

# Hello World
track("Hello World", list(language = "r"))
```

### Perl

```perl
use JSON;

sub track {
    my ($event, $props_ref) = @_;
    my $token = $ENV{MIXPANEL_TOKEN};
    my $json = encode_json($props_ref);
    system(1, "./mixpanel-micro.sh", $token, $event, $json, "perl_user");
}

# Hello World
track("Hello World", { language => "perl" });
```

### Lua

```lua
local cjson = require "cjson"

local function track(event, props)
    local token = os.getenv("MIXPANEL_TOKEN")
    local json_str = cjson.encode(props)
    local cmd = string.format(
        "./mixpanel-micro.sh '%s' '%s' '%s' 'lua_user'",
        token, event, json_str
    )
    os.execute(cmd)
end

-- Hello World
track("Hello World", { language = "lua" })
```

### Bash / Shell

```bash
#!/bin/bash

track() {
    local event=$1
    local props=${2:-"{}"}
    ./mixpanel-micro.sh "$MIXPANEL_TOKEN" "$event" "$props" "$(whoami)"
}

# Hello World
track "Hello World" '{"language": "bash"}'
```

### AWK

Track events directly from text-processing pipelines:

```awk
#!/usr/bin/awk -f
# analytics.awk - Track events from AWK scripts

function track(event, props) {
    cmd = sprintf("./mixpanel-micro.sh '%s' '%s' '%s' 'awk_user' &",
                  ENVIRON["MIXPANEL_TOKEN"], event, props)
    system(cmd)
}

BEGIN {
    track("AWK Script Started", "{\"file\": \"" FILENAME "\"}")
}

# Process lines and track interesting events
/ERROR/ {
    track("Error Found", "{\"line\": " NR ", \"content\": \"" $0 "\"}")
}

END {
    track("AWK Script Finished", "{\"lines_processed\": " NR "}")
}
```

### Deno

Modern TypeScript runtime with built-in tooling:

```typescript
// analytics.ts
const SCRIPT_PATH = "./mixpanel-micro.sh";

function createTracker(token: string, distinctId: string) {
  return async (event: string, props: Record<string, unknown> = {}) => {
    const command = new Deno.Command(SCRIPT_PATH, {
      args: [token, event, JSON.stringify(props), distinctId],
      stdout: "null",
      stderr: "null",
    });
    command.spawn(); // Fire and forget
  };
}

// Hello World
const track = createTracker(Deno.env.get("MIXPANEL_TOKEN")!, "deno_user");
await track("Hello World", { runtime: "deno", version: Deno.version.deno });
```

### Bun

High-performance JavaScript runtime:

```typescript
// analytics.ts
const SCRIPT_PATH = "./mixpanel-micro.sh";

function createTracker(token: string, distinctId: string) {
  return (event: string, props: Record<string, unknown> = {}) => {
    Bun.spawn([SCRIPT_PATH, token, event, JSON.stringify(props), distinctId], {
      stdout: "ignore",
      stderr: "ignore",
    });
  };
}

// Hello World
const track = createTracker(Bun.env.MIXPANEL_TOKEN!, "bun_user");
track("Hello World", { runtime: "bun", version: Bun.version });
```

### Julia

For scientific computing, data science, and ML workflows:

```julia
using JSON3

function create_tracker(token::String, distinct_id::String)
    return function track(event::String, props::Dict=Dict())
        props_json = JSON3.write(props)
        run(`./mixpanel-micro.sh $token $event $props_json $distinct_id`, wait=false)
    end
end

# Hello World
track = create_tracker(ENV["MIXPANEL_TOKEN"], "julia_user")
track("Hello World", Dict("language" => "julia", "version" => string(VERSION)))
```

### Clojure

Functional programming on the JVM:

```clojure
(ns analytics
  (:require [cheshire.core :as json]))

(defn create-tracker [token distinct-id]
  (fn [event & [props]]
    (let [props-json (json/generate-string (or props {}))]
      (.start (ProcessBuilder. ["./mixpanel-micro.sh" token event props-json distinct-id])))))

;; Hello World
(def track (create-tracker (System/getenv "MIXPANEL_TOKEN") "clojure_user"))
(track "Hello World" {:language "clojure"})
```

### Dart

For Flutter apps and server-side Dart:

```dart
import 'dart:convert';
import 'dart:io';

class Tracker {
  final String token;
  final String distinctId;

  Tracker(this.token, this.distinctId);

  Future<void> track(String event, [Map<String, dynamic>? props]) async {
    await Process.start(
      './mixpanel-micro.sh',
      [token, event, jsonEncode(props ?? {}), distinctId],
      mode: ProcessStartMode.detached,
    );
  }
}

// Hello World
void main() async {
  final tracker = Tracker(Platform.environment['MIXPANEL_TOKEN']!, 'dart_user');
  await tracker.track('Hello World', {'language': 'dart'});
}
```

### Groovy

For Jenkins pipelines, Gradle builds, and JVM scripting:

```groovy
import groovy.json.JsonOutput

class Tracker {
    String token
    String distinctId

    Tracker(String token, String distinctId) {
        this.token = token
        this.distinctId = distinctId
    }

    void track(String event, Map props = [:]) {
        def propsJson = JsonOutput.toJson(props)
        ["./mixpanel-micro.sh", token, event, propsJson, distinctId].execute()
    }
}

// Hello World
def mp = new Tracker(System.getenv("MIXPANEL_TOKEN"), "groovy_user")
mp.track("Hello World", [language: "groovy"])
```

### Crystal

Ruby-like syntax with C-like performance:

```crystal
require "json"

class Tracker
  def initialize(@token : String, @distinct_id : String)
  end

  def track(event : String, props = {} of String => String)
    Process.new(
      "./mixpanel-micro.sh",
      [@token, event, props.to_json, @distinct_id]
    )
  end
end

# Hello World
tracker = Tracker.new(ENV["MIXPANEL_TOKEN"], "crystal_user")
tracker.track("Hello World", {"language" => "crystal"})
```

### Nim

Python-like syntax, C-like performance:

```nim
import std/[json, osproc, os]

proc createTracker(token, distinctId: string): proc(event: string, props: JsonNode) =
  return proc(event: string, props: JsonNode = %*{}) =
    discard startProcess(
      "./mixpanel-micro.sh",
      args = [token, event, $props, distinctId]
    )

# Hello World
let track = createTracker(getEnv("MIXPANEL_TOKEN"), "nim_user")
track("Hello World", %*{"language": "nim"})
```

### Erlang

For telecom-grade distributed systems:

```erlang
-module(analytics).
-export([track/3, track/4]).

track(Event, Props, DistinctId) ->
    Token = os:getenv("MIXPANEL_TOKEN"),
    track(Token, Event, Props, DistinctId).

track(Token, Event, Props, DistinctId) ->
    PropsJson = jsx:encode(Props),
    Cmd = io_lib:format("./mixpanel-micro.sh '~s' '~s' '~s' '~s' &",
                        [Token, Event, PropsJson, DistinctId]),
    os:cmd(lists:flatten(Cmd)).

%% Hello World
%% analytics:track("Hello World", #{language => <<"erlang">>}, "erlang_user").
```

---

## Real-World Use Cases

### Monitoring Backup Scripts

```bash
#!/bin/bash
TOKEN="YOUR_TOKEN"

./mixpanel-micro.sh "$TOKEN" "Backup Started" '{"server": "db-01"}'

# Run backup
if pg_dump mydb > backup.sql; then
    SIZE=$(stat -f%z backup.sql)
    ./mixpanel-micro.sh "$TOKEN" "Backup Success" "{\"size_bytes\": $SIZE}"
else
    ./mixpanel-micro.sh "$TOKEN" "Backup Failed" '{"server": "db-01"}'
fi
```

### Tracking Build Durations

```javascript
// build.js
const { performance } = require('perf_hooks');
const start = performance.now();

// Your build logic here
require('./webpack.config.js').build();

const duration = Math.round(performance.now() - start);
track('Build Complete', { duration_ms: duration });
```

### IoT Sensor Network

```python
# sensor_network.py
import time
import random

track = create_tracker(os.getenv("MIXPANEL_TOKEN"), f"sensor_{SENSOR_ID}")

while True:
    temp = read_temperature_sensor()
    humidity = read_humidity_sensor()

    track("Sensor Reading", {
        "temperature": temp,
        "humidity": humidity,
        "battery_level": get_battery_level()
    })

    time.sleep(300)  # Every 5 minutes
```


### Error Monitoring

```go
// Monitor panics in Go services
func trackPanic() {
    if r := recover(); r != nil {
        mp.Track("Service Panic", map[string]interface{}{
            "error": fmt.Sprintf("%v", r),
            "stack": string(debug.Stack()),
        })
        panic(r) // Re-panic after tracking
    }
}

defer trackPanic()
```

### ML Training Loop (PyTorch)

Track training progress, epochs, and model performance:

```python
# train.py
import subprocess
import json
import os

def track(event, props={}):
    subprocess.Popen([
        './mixpanel-micro.sh',
        os.environ['MIXPANEL_TOKEN'],
        event,
        json.dumps(props),
        f"training_{os.environ.get('SLURM_JOB_ID', 'local')}"
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Track training start
track("Training Started", {
    "model": "resnet50",
    "dataset": "imagenet",
    "batch_size": 32,
    "learning_rate": 0.001,
    "gpu": torch.cuda.get_device_name(0) if torch.cuda.is_available() else "cpu"
})

for epoch in range(num_epochs):
    train_loss = train_one_epoch(model, dataloader)
    val_loss, val_acc = validate(model, val_loader)

    # Track each epoch
    track("Epoch Complete", {
        "epoch": epoch + 1,
        "train_loss": round(train_loss, 4),
        "val_loss": round(val_loss, 4),
        "val_accuracy": round(val_acc, 4)
    })

    if val_acc > best_acc:
        best_acc = val_acc
        track("New Best Model", {"accuracy": round(val_acc, 4), "epoch": epoch + 1})

# Track training complete
track("Training Complete", {
    "final_accuracy": round(best_acc, 4),
    "total_epochs": num_epochs
})
```

### Makefile Integration

Track build targets and durations:

```makefile
# Makefile
MIXPANEL_TOKEN ?= your_token
TRACK = ./mixpanel-micro.sh "$(MIXPANEL_TOKEN)"

.PHONY: build test deploy

build:
	@$(TRACK) "Build Started" '{"target": "build"}'
	@START=$$(date +%s); \
	go build -o bin/app ./cmd/app && \
	DURATION=$$((($$(date +%s) - $$START))); \
	$(TRACK) "Build Complete" "{\"target\": \"build\", \"duration_sec\": $$DURATION}"

test:
	@$(TRACK) "Tests Started" '{"target": "test"}'
	@go test ./... && \
	$(TRACK) "Tests Passed" '{"target": "test"}' || \
	$(TRACK) "Tests Failed" '{"target": "test"}'

deploy:
	@$(TRACK) "Deploy Started" '{"environment": "$(ENV)"}'
	@kubectl apply -f k8s/ && \
	$(TRACK) "Deploy Complete" '{"environment": "$(ENV)"}'
```

### Data Pipeline (Airflow)

Track DAG runs and task execution:

```python
# dags/analytics_dag.py
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import subprocess
import json
import os

def track(event, props={}):
    props['dag_id'] = 'etl_pipeline'
    props['run_id'] = '{{ run_id }}'
    subprocess.Popen([
        './mixpanel-micro.sh',
        os.environ['MIXPANEL_TOKEN'],
        event,
        json.dumps(props),
        'airflow'
    ])

def extract(**context):
    track("ETL Extract Started", {"source": "postgres"})
    # ... extraction logic
    rows = extract_from_source()
    track("ETL Extract Complete", {"rows": len(rows)})
    return rows

def transform(**context):
    track("ETL Transform Started", {})
    # ... transformation logic
    track("ETL Transform Complete", {"transformations": 5})

def load(**context):
    track("ETL Load Started", {"destination": "bigquery"})
    # ... load logic
    track("ETL Load Complete", {"rows_loaded": 10000})

with DAG('etl_pipeline', start_date=datetime(2024, 1, 1), schedule='@daily') as dag:
    extract_task = PythonOperator(task_id='extract', python_callable=extract)
    transform_task = PythonOperator(task_id='transform', python_callable=transform)
    load_task = PythonOperator(task_id='load', python_callable=load)

    extract_task >> transform_task >> load_task
```

### File Watcher (fswatch/inotify)

Track file system changes in real-time:

```bash
#!/bin/bash
# watch_uploads.sh - Track file uploads to a directory

TOKEN="YOUR_TOKEN"
WATCH_DIR="/var/uploads"

track() {
    ./mixpanel-micro.sh "$TOKEN" "$1" "$2" "file_watcher"
}

track "File Watcher Started" "{\"directory\": \"$WATCH_DIR\"}"

# Using fswatch (macOS/Linux) or inotifywait (Linux)
if command -v fswatch &> /dev/null; then
    fswatch -0 "$WATCH_DIR" | while read -d "" file; do
        SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        EXT="${file##*.}"
        track "File Uploaded" "{\"path\": \"$file\", \"size_bytes\": $SIZE, \"extension\": \"$EXT\"}"
    done
elif command -v inotifywait &> /dev/null; then
    inotifywait -m -e create -e moved_to "$WATCH_DIR" --format '%w%f' | while read file; do
        SIZE=$(stat -c%s "$file" 2>/dev/null)
        EXT="${file##*.}"
        track "File Uploaded" "{\"path\": \"$file\", \"size_bytes\": $SIZE, \"extension\": \"$EXT\"}"
    done
fi
```

### Webhook Handler

Track incoming webhooks from any source:

```python
# webhook_server.py
from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import json
import os

def track(event, props={}):
    subprocess.Popen([
        './mixpanel-micro.sh',
        os.environ['MIXPANEL_TOKEN'],
        event,
        json.dumps(props),
        'webhook_handler'
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)

        # Track the webhook
        track("Webhook Received", {
            "path": self.path,
            "source": self.headers.get('X-Webhook-Source', 'unknown'),
            "content_type": self.headers.get('Content-Type', 'unknown'),
            "size_bytes": content_length
        })

        # Process webhook...
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')

if __name__ == '__main__':
    track("Webhook Server Started", {"port": 8080})
    HTTPServer(('', 8080), WebhookHandler).serve_forever()
```

### PostgreSQL pg_cron

Track scheduled database jobs:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a wrapper function for tracking
CREATE OR REPLACE FUNCTION track_event(event_name TEXT, props JSONB DEFAULT '{}')
RETURNS void AS $$
BEGIN
    -- Fire and forget using pg_background or similar
    PERFORM pg_background_launch(format(
        $cmd$./mixpanel-micro.sh '%s' '%s' '%s' 'postgres'$cmd$,
        current_setting('app.mixpanel_token'),
        event_name,
        props::text
    ));
END;
$$ LANGUAGE plpgsql;

-- Alternative: Use COPY to a program (simpler, no extension needed)
CREATE OR REPLACE FUNCTION track_via_copy(event_name TEXT, props JSONB DEFAULT '{}')
RETURNS void AS $$
BEGIN
    EXECUTE format(
        $cmd$COPY (SELECT 1) TO PROGRAM './mixpanel-micro.sh ''%s'' ''%s'' ''%s'' ''postgres'''$cmd$,
        current_setting('app.mixpanel_token'),
        event_name,
        props::text
    );
END;
$$ LANGUAGE plpgsql;

-- Schedule a job that tracks itself
SELECT cron.schedule('nightly-cleanup', '0 3 * * *', $$
    SELECT track_event('DB Cleanup Started', '{"job": "nightly-cleanup"}');
    DELETE FROM logs WHERE created_at < NOW() - INTERVAL '30 days';
    SELECT track_event('DB Cleanup Complete', jsonb_build_object('rows_deleted', (SELECT COUNT(*) FROM logs)));
$$);
```

### Redis Queue Consumer

Track job processing from Redis queues:

```python
# worker.py
import redis
import json
import subprocess
import os
import time

def track(event, props={}):
    subprocess.Popen([
        './mixpanel-micro.sh',
        os.environ['MIXPANEL_TOKEN'],
        event,
        json.dumps(props),
        f"worker_{os.getpid()}"
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

r = redis.Redis(host='localhost', port=6379)
track("Worker Started", {"queue": "jobs"})

while True:
    # Blocking pop from queue
    _, job_data = r.brpop('jobs')
    job = json.loads(job_data)

    start_time = time.time()
    track("Job Started", {"job_id": job['id'], "type": job['type']})

    try:
        # Process the job
        result = process_job(job)
        duration = time.time() - start_time

        track("Job Complete", {
            "job_id": job['id'],
            "type": job['type'],
            "duration_sec": round(duration, 2),
            "status": "success"
        })

    except Exception as e:
        duration = time.time() - start_time
        track("Job Failed", {
            "job_id": job['id'],
            "type": job['type'],
            "duration_sec": round(duration, 2),
            "error": str(e)
        })
```

### SSH Remote Execution

Track commands executed on remote servers:

```bash
#!/bin/bash
# remote_exec.sh - Execute commands on remote servers with tracking

TOKEN="YOUR_TOKEN"
HOSTS="server1.example.com server2.example.com server3.example.com"

track() {
    ./mixpanel-micro.sh "$TOKEN" "$1" "$2" "remote_exec"
}

run_remote() {
    local host=$1
    local cmd=$2

    track "Remote Command Started" "{\"host\": \"$host\", \"command\": \"$cmd\"}"

    START=$(date +%s)
    if ssh "$host" "$cmd" 2>&1; then
        DURATION=$(($(date +%s) - START))
        track "Remote Command Success" "{\"host\": \"$host\", \"duration_sec\": $DURATION}"
        return 0
    else
        DURATION=$(($(date +%s) - START))
        track "Remote Command Failed" "{\"host\": \"$host\", \"duration_sec\": $DURATION}"
        return 1
    fi
}

# Deploy to all hosts
track "Deployment Started" "{\"hosts\": $#}"
for host in $HOSTS; do
    run_remote "$host" "cd /app && git pull && systemctl restart app"
done
track "Deployment Complete" "{\"hosts\": $#}"
```

---

## How It Works

1. **Accepts arguments**: TOKEN, EVENT, JSON properties, optional distinct_id
2. **Auto-generates ID**: If no distinct_id provided, uses `hostname-username`
3. **Builds payload**: Constructs Mixpanel-compatible JSON
4. **Async execution**: Spawns a backgrounded function for fire-and-forget behavior
5. **Universal HTTP**: Tries curl, then wget, then httpie
6. **Returns immediately**: Parent process exits in <50ms

The entire HTTP request happens in the background, so it never blocks your application.


## Requirements

- POSIX-compliant shell (sh, bash, zsh, dash, BusyBox, etc.)
- One of: `curl`, `wget`, or `httpie`
- Internet access to api.mixpanel.com

## Debugging

### Check which HTTP client will be used

```bash
command -v curl || command -v wget || command -v httpie
```

### See the exact payload being sent + response

```bash
./mixpanel-micro.sh "TOKEN" "Event" '{"test": true}' "user" --verbose
```

### Test without sending data

```bash
./mixpanel-micro.sh "TOKEN" "Event" '{"test": true}' "user" --dry-run
```

### Verify events in Mixpanel

All events are tagged with `"$source": "mixpanel-micro"` so you can filter them in the Mixpanel UI.

## Testing

Run the test suite with [BATS](https://github.com/bats-core/bats-core):

```bash
bats test.bats
```

