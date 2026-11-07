#!/usr/bin/env python3
"""Rebuilds Packages / Packages.gz / Packages.bz2 / Release from every .deb in debs/ (needs dpkg-deb)."""
import os, subprocess, hashlib, gzip, bz2, json, time, re
BASE = "https://hgphutjb.github.io/repo"
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)

def field_order(fields):
    order = ["Package", "Version", "Architecture", "Maintainer", "Depends", "Conflicts", "Replaces", "Provides", "Filename", "Size", "MD5sum", "SHA1", "SHA256", "Section", "Name", "Author", "Icon", "Depiction", "SileoDepiction", "Description"]
    return [k for k in order if k in fields] + [k for k in fields if k not in order]

def parse_control(text):
    fields, key = {}, None
    for line in text.splitlines():
        if line.startswith((" ", "\t")) and key:
            fields[key] += "\n" + line
        elif ":" in line:
            key, val = line.split(":", 1); fields[key.strip()] = val.strip()
    return fields

def newest(files):
    def ver(f):
        v = re.search(r"_([0-9][^_]*)_", f).group(1)
        return [int(x) if x.isdigit() else 0 for x in re.split(r"[.\-]", v)]
    best = {}
    for f in files:
        pkg = f.split("_")[0]
        if pkg not in best or ver(f) > ver(best[pkg]): best[pkg] = f
    return sorted(best.values())

entries = []
metas = []
for f in newest([x for x in os.listdir("debs") if x.endswith(".deb")]):
    path = os.path.join("debs", f)
    ctrl = parse_control(subprocess.check_output(["dpkg-deb", "-f", path]).decode())
    data = open(path, "rb").read()
    for k in ("Header", "Suggests_"): ctrl.pop(k, None)
    pid = ctrl["Package"]
    ctrl["Filename"] = "debs/" + f
    ctrl["Size"] = str(len(data))
    ctrl["MD5sum"] = hashlib.md5(data).hexdigest()
    ctrl["SHA1"] = hashlib.sha1(data).hexdigest()
    ctrl["SHA256"] = hashlib.sha256(data).hexdigest()
    ctrl["Icon"] = BASE + ("/icons/" + pid + ".png" if os.path.exists("icons/" + pid + ".png") else "/icon.png")
    ctrl["Depiction"] = BASE + "/depictions/web/" + pid + ".html"
    ctrl["SileoDepiction"] = BASE + "/depictions/" + pid + ".json"
    metas.append(dict(ctrl))
    entries.append("\n".join("%s: %s" % (k, ctrl[k]) for k in field_order(ctrl)))
pk = ("\n\n".join(entries) + "\n").encode()
open("Packages", "wb").write(pk)
with gzip.GzipFile("Packages.gz", "wb", mtime=0) as g: g.write(pk)
open("Packages.bz2", "wb").write(bz2.compress(pk, 9))

def h(fn, algo):
    return getattr(hashlib, algo)(open(fn, "rb").read()).hexdigest()
files = ["Packages", "Packages.gz", "Packages.bz2"]
rel = ["Origin: PucPucPuc", "Label: PucPucPuc", "Suite: stable", "Version: 1.0", "Codename: ios", "Architectures: iphoneos-arm",
       "Components: main", "Description: Repo của PucPucPuc: tweak 2712 (giao diện iOS 26 cho iOS 12)",
       "Date: " + time.strftime("%a, %d %b %Y %H:%M:%S UTC", time.gmtime())]
for algo, name in (("md5", "MD5Sum"), ("sha1", "SHA1"), ("sha256", "SHA256")):
    rel.append(name + ":")
    for fn in files: rel.append(" %s %d %s" % (h(fn, algo), os.path.getsize(fn), fn))
open("Release", "w").write("\n".join(rel) + "\n")

# ---- landing page (rebuilt from the packages, so it never goes out of date) ----
import html as _h
def card(m):
    return ('<a class="c" href="depictions/web/%s.html"><img src="%s" alt=""><span><b>%s</b><i>v%s</i><em>%s</em></span></a>'
            % (m["Package"], _h.escape(m["Icon"].replace(BASE + "/", "")), _h.escape(m.get("Name", m["Package"])), _h.escape(m["Version"]), _h.escape(m.get("Description", "").split("\n")[0])))
order = ["com.wave12.suite"]
rest = sorted([m for m in metas if m["Package"] not in order and m["Package"] != "com.puc.claudemini"], key=lambda m: m.get("Name", "").lower())
apps = [m for m in metas if m["Package"] == "com.puc.claudemini"]
suite = [m for m in metas if m["Package"] == "com.wave12.suite"]
page = """<!doctype html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Repo PucPucPuc</title>
<meta name="description" content="Nguồn tweak cho iOS 12 (rootful): bộ 2712 giao diện kiểu iOS 26 và các tweak riêng lẻ.">
<style>:root{--bg:#fff;--fg:#111;--mut:#6b6b70;--card:#f2f2f7;--ac:#34c759;--ln:#e5e5ea}@media(prefers-color-scheme:dark){:root{--bg:#000;--fg:#f2f2f7;--mut:#98989d;--card:#1c1c1e;--ln:#2c2c2e}}
*{box-sizing:border-box}body{font:16px/1.5 -apple-system,Helvetica,sans-serif;margin:0;padding:24px 16px 48px;background:var(--bg);color:var(--fg);max-width:600px;margin-inline:auto}
header{display:flex;gap:14px;align-items:center}header img{width:72px;height:72px;border-radius:16px}h1{margin:0;font-size:26px}p{color:var(--mut);margin:.2em 0}
h2{font-size:14px;text-transform:uppercase;letter-spacing:.06em;color:var(--mut);margin:28px 0 8px}
code{background:var(--card);padding:.6em .8em;border-radius:10px;display:block;word-break:break-all;color:var(--fg);font-size:14px;margin-top:8px}
.b{display:inline-block;margin:8px 8px 0 0;padding:.55em 1em;border-radius:999px;background:var(--ac);color:#fff;text-decoration:none;font-weight:600;font-size:15px}
.c{display:flex;gap:12px;align-items:center;padding:10px 12px;margin-bottom:8px;background:var(--card);border-radius:14px;color:var(--fg);text-decoration:none}
.c img{width:48px;height:48px;border-radius:11px;flex:none}.c span{display:block;min-width:0}.c b{display:block}.c i{font-style:normal;color:var(--mut);font-size:13px;margin-left:0}.c em{display:block;font-style:normal;color:var(--mut);font-size:14px}
footer{margin-top:28px;color:var(--mut);font-size:13px}</style></head><body>
<header><img src="icon.png" alt=""><div><h1>Repo PucPucPuc</h1><p>Nguồn tweak cho iOS 12 (rootful)</p></div></header>
<h2>Thêm nguồn</h2><code>https://hgphutjb.github.io/repo/</code>
<a class="b" href="sileo://source/https://hgphutjb.github.io/repo/">Thêm vào Sileo</a><a class="b" href="zbra://sources/add/https://hgphutjb.github.io/repo/">Thêm vào Zebra</a><a class="b" href="cydia://url/https://cydia.saurik.com/api/share#?source=https://hgphutjb.github.io/repo/">Thêm vào Cydia</a>
<h2>Cài một lần</h2>""" + "".join(card(m) for m in suite) + """
<h2>Từng tweak (cài riêng được)</h2>""" + "".join(card(m) for m in rest) + """
<h2>Ứng dụng</h2>""" + "".join(card(m) for m in apps) + """
<footer>Cập nhật """ + time.strftime("%d/%m/%Y", time.gmtime()) + """. Các tweak chưa được kiểm tra hết trên máy thật, hãy sao lưu trước khi cài.</footer></body></html>"""
open("index.html", "w", encoding="utf-8").write(page)
print("packages:", len(entries))
