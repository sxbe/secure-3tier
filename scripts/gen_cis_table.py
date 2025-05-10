import re, glob, pathlib

out = []

# look through every *.tf file in the repo root
for tf_file in glob.glob("*.tf"):
    with open(tf_file) as fh:
        for line in fh:
            # capture comments like  # CIS_1_1
            match = re.search(r"#\s*(CIS_\d+_\d+)", line)
            if match:
                out.append(
                    {
                        "control": match.group(1),
                        "file": tf_file,
                        "line": line.strip(),
                    }
                )

# build a Markdown table
table = (
    "| CIS Control | Terraform snippet |\n| --- | --- |\n"
    + "\n".join(f"| {d['control']} | `{d['line']}` |" for d in out)
)

# write to controls.md at repo root
pathlib.Path("controls.md").write_text(table)
print("controls.md generated")
