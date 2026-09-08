from concurrent.futures import ThreadPoolExecutor
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

with urllib.request.urlopen(base_url + "/", timeout=10) as response:
    assert b"{{" not in response.read()

print("Packaged startup, assets, and concurrent increments passed")
