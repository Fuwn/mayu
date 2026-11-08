from concurrent.futures import ThreadPoolExecutor

import gzip
import json
import sys
import time
import urllib.request
import uuid
import xml.etree.ElementTree as xml

base_url = sys.argv[1].rstrip("/")

for attempt in range(100):
    try:
        with urllib.request.urlopen(base_url + "/heart-beat", timeout=1) as response:
            assert response.read() == b"alive"

        break
    except (OSError, AssertionError):
        time.sleep(0.1)
else:
    raise RuntimeError("Mayu did not become ready")

counter_name = "smoke-" + uuid.uuid4().hex

def record_hit(_=None):
    with urllib.request.urlopen(base_url + "/record/@" + counter_name, timeout=10) as response:
        return json.load(response)["num"]

assert record_hit() == 1

with urllib.request.urlopen(base_url + "/get/@" + counter_name, timeout=10) as response:
    document = xml.fromstring(response.read())

    assert response.headers.get_content_type() == "image/svg+xml"
    assert int(document.attrib["width"]) > 0
    assert int(document.attrib["height"]) > 0
    assert document.find(".//{http://www.w3.org/2000/svg}image") is not None

with ThreadPoolExecutor(max_workers=20) as executor:
    counts = sorted(executor.map(record_hit, range(20)))

assert counts == list(range(3, 23)), counts

large_image_request = urllib.request.Request(
    base_url + "/get/@" + counter_name + "-gzip?theme=lain&padding=12",
    headers={"Accept-Encoding": "gzip"},
)

with urllib.request.urlopen(large_image_request, timeout=10) as response:
    document = xml.fromstring(gzip.decompress(response.read()))

    assert response.headers["Content-Encoding"] == "gzip"
    assert response.headers["Vary"] == "Accept-Encoding"
    assert document.find(".//{http://www.w3.org/2000/svg}image") is not None

with urllib.request.urlopen(base_url + "/", timeout=10) as response:
    homepage = response.read()

    assert b"{{" not in homepage
    assert b"(v" in homepage

print("Packaged startup, assets, concurrent increments, and gzip passed")
