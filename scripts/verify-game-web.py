#!/usr/bin/env python3
"""Real-browser acceptance for a Godot web game under public/games/<game>/<ver>/.

Checks (each PASS/FAIL, written to <out>/report.json):
  1. build-info.json sourceSha matches --sha (deployed target only) and dirty is false
  2. index.html / index.js / index.wasm / index.pck return 200, sizes equal the committed files
  3. .wasm served as application/wasm
  4. Godot engine boots (loading overlay removed), no page errors / console errors
  5. Title canvas renders non-blank; clicking the first menu button changes the canvas
Exit 0 = PASS, 1 = FAIL, 2 = BLOCKED (network error on the verifying machine; rerun, do not report as site FAIL).
Requires Playwright + Pillow (see scripts/browser-requirements.txt). Headless Chromium uses SwiftShader WebGL.
It is a smoke test, not gameplay, device-performance or art acceptance.
"""
import argparse, io, json, time, urllib.request
from pathlib import Path
from PIL import Image, ImageChops
from playwright.sync_api import sync_playwright

FILES = ["index.html", "index.js", "index.wasm", "index.pck"]


def fetch(u, tries=4):
    """GET with retries: large .wasm downloads over flaky links can end early; that is a network blocker, not a site FAIL."""
    err = None
    for i in range(tries):
        try:
            r = urllib.request.urlopen(u, timeout=180)
            return r.status, r.headers, r.read()
        except Exception as e:  # IncompleteRead, SSL EOF, timeouts
            err = e
            time.sleep(2 * (i + 1))
    raise RuntimeError(f"BLOCKED network: {u}: {err}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True, help="game page, e.g. http://127.0.0.1:4196/games/momen-rencai/v1/")
    ap.add_argument("--local", required=True, help="committed export dir, e.g. public/games/momen-rencai/v1")
    ap.add_argument("--sha", help="expected build-info sourceSha (deployed target)")
    ap.add_argument("--site-root", help="URL whose build-info.json to read; default: two levels above --url's games/")
    ap.add_argument("--click", default="0.5,0.34", help="first menu button, as fraction of canvas x,y")
    ap.add_argument("--boot-wait", type=float, default=15.0, help="seconds; boot timeout is 4x this")
    ap.add_argument("--out", default="verification/game-web")
    a = ap.parse_args()
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    url = a.url if a.url.endswith("/") else a.url + "/"
    rep = {"url": url, "startedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "checks": [],
           "gameplay": "NOT_RUN", "devicePerformance": "NOT_RUN", "artApproval": "PENDING"}
    ok = True
    net = []

    def check(name, cond, detail=""):
        nonlocal ok
        rep["checks"].append({"name": name, "status": "PASS" if cond else "FAIL", "detail": str(detail)})
        ok = ok and bool(cond)
        print(("PASS " if cond else "FAIL ") + name, detail)

    bust = f"?t={int(time.time())}"
    if a.sha:
        root = a.site_root or url.split("/games/")[0] + "/"
        info = json.loads(fetch(root + "build-info.json" + bust)[2])
        check("build-info sourceSha", info.get("sourceSha") == a.sha, info.get("sourceSha"))
        check("build-info not dirty", info.get("dirty") is False, info.get("dirty"))
    for f in FILES:
        status, headers, body = fetch(url + f + bust)
        want = (Path(a.local) / f).stat().st_size
        check(f"{f} 200 and size", status == 200 and len(body) == want, f"{len(body)} vs committed {want}")
        if f.endswith(".wasm"):
            check("wasm MIME", "application/wasm" in headers.get("Content-Type", ""), headers.get("Content-Type"))

    with sync_playwright() as pw:
        b = pw.chromium.launch(args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader"])
        pg = b.new_page(viewport={"width": 540, "height": 960})
        logs, errs = [], []
        pg.on("console", lambda m: (logs.append(m.text), errs.append(m.text) if m.type == "error" else None))
        pg.on("pageerror", lambda e: errs.append(str(e)))
        pg.goto(url, timeout=120000)
        t0 = time.time()
        try:  # Godot's shell removes #status once the engine has started; a load error shows #status-notice instead
            pg.wait_for_function("!document.getElementById('status')", timeout=a.boot_wait * 4 * 1000)
            booted = True
        except Exception:
            booted = False
        check("Godot engine boots (status overlay removed)", booted, f"{time.time() - t0:.1f}s")
        time.sleep(a.boot_wait / 5)  # let the title screen draw
        pg.screenshot(path=str(out / "title.png"))
        t = Image.open(out / "title.png").convert("RGB")
        check("title canvas not blank", len(set(t.resize((54, 96)).getdata())) > 20)
        fx, fy = (float(v) for v in a.click.split(","))
        pg.mouse.click(540 * fx, 960 * fy)
        time.sleep(3)
        pg.screenshot(path=str(out / "after-click.png"))
        c = Image.open(out / "after-click.png").convert("RGB")
        changed = sum(1 for px in ImageChops.difference(t, c).getdata() if max(px) > 8)
        check("first menu button responds", changed > 5000, f"{changed} px changed")
        check("no console/page errors", not errs, errs[:5])
        net = [e for e in errs if "net::ERR_" in e or e.strip() == "network error"]
        b.close()

    # a dropped connection in the verifying machine is not evidence about the site
    rep["runtime"] = "PASS" if ok else ("BLOCKED" if net else "FAIL")
    if net:
        rep["blockedBy"] = net[:3]
    (out / "report.json").write_text(json.dumps(rep, ensure_ascii=False, indent=1))
    print("RUNTIME", rep["runtime"], "->", out / "report.json")
    raise SystemExit(0 if ok else (2 if net else 1))


if __name__ == "__main__":
    main()
