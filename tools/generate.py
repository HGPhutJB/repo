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
    ctrl["Icon"] = BASE + "/icon.png"
    ctrl["Depiction"] = BASE + "/depictions/web/" + pid + ".html"
    ctrl["SileoDepiction"] = BASE + "/depictions/" + pid + ".json"
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
print("packages:", len(entries))
