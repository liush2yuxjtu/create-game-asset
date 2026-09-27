"""口播生成：python3 tools/tts.py "<台词>" <voice> <out.mp3> [rate]  → out.mp3 + out.mp3.json（词级时间）

走代理时读取 HTTPS_PROXY；自签 CA 读取 SSL_CERT_FILE。批量生成见 assets/vo/lines.tsv。
"""
import asyncio, json, os, sys
import certifi

if os.environ.get("SSL_CERT_FILE"):
    certifi.where = lambda: os.environ["SSL_CERT_FILE"]
import edge_tts


async def main(text, voice, out, rate="+0%"):
    c = edge_tts.Communicate(text, voice, rate=rate, proxy=os.environ.get("HTTPS_PROXY"), boundary="WordBoundary")
    words = []
    with open(out, "wb") as f:
        async for ch in c.stream():
            if ch["type"] == "audio":
                f.write(ch["data"])
            elif ch["type"] == "WordBoundary":
                words.append((ch["offset"] / 1e7, ch["duration"] / 1e7, ch["text"]))
    json.dump(words, open(out + ".json", "w"), ensure_ascii=False)


if __name__ == "__main__":
    asyncio.run(main(*sys.argv[1:]))
