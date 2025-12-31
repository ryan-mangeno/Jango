#!/usr/bin/env python3

import platform
import re
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
PLATFORM_DIR = ROOT / "Crimson/src/Platform"

OPENGL_DIR = PLATFORM_DIR / "OpenGL"
METAL_DIR  = PLATFORM_DIR / "Metal"
STUBS_DIR  = PLATFORM_DIR / "Stubs"

ASSERT_HEADER = "Crimson/Core/Log.h"
STUB_SUFFIX = ".stub.cpp"

# Regex Patterns

# Matches "class Name"
CLASS_REGEX = re.compile(r"\bclass\s+([A-Za-z0-9_]+)")

# Matches Constructors: "Name(...)"
CTOR_REGEX = re.compile(r"^([A-Za-z0-9_]+)\s*\(([^)]*)\)")

# Matches Destructors: "~Name(...)"
DTOR_REGEX = re.compile(r"^~([A-Za-z0-9_]+)\s*\(([^)]*)\)")

# Matches Methods: "Type Name(Args) [const]"
# Capture groups: 1=Type, 2=Name, 3=Args, 4=Suffix
METHOD_REGEX = re.compile(
    r"^(?!return)(?:[\w:<>*&]+\s+)*?([\w:<>*&]+)\s+(\w+)\s*\(([^)]*)\)([\w\s]*)$"
)

# Platform Setup

system = platform.system()
if system == "Darwin":
    REAL_BACKEND = "Metal"
    STUB_BACKEND = "OpenGL"
    SOURCE_DIR = OPENGL_DIR
elif system in ("Windows", "Linux"):
    REAL_BACKEND = "OpenGL"
    STUB_BACKEND = "Metal"
    SOURCE_DIR = METAL_DIR
else:
    raise RuntimeError(f"Unsupported platform: {system}")

OUTPUT_DIR = STUBS_DIR / STUB_BACKEND

# Helpers
def remove_comments(text):
    def replacer(match):
        s = match.group(0)
        if s.startswith('/'): return " "
        return s
    pattern = re.compile(
        r'//.*?$|/\*.*?\*/|\'(?:\\.|[^\\\'])*\'|"(?:\\.|[^\\"])*"',
        re.DOTALL | re.MULTILINE
    )
    return re.sub(pattern, replacer, text)

def strip_default_args(param_str):
    if not param_str: return ""
    # Removes " = something" from arguments
    # Ex: "int a = 0, float b = 5.0f" -> "int a, float b"
    return re.sub(r"\s*=\s*[^,)]+", "", param_str)

def default_return_value(return_type):
    return_type = return_type.strip()
    if return_type in ("void", "void*"): return "" if return_type == "void" else "nullptr"
    if return_type == "bool": return "false"
    if "*" in return_type or "Ref<" in return_type or "Scope<" in return_type: return "nullptr"
    if return_type in ("uint32_t", "int", "size_t", "unsigned int", "long", "uint64_t"): return "0"
    if return_type in ("float", "double"): return "0.0f"
    return "{}" 

def clean_statement(stmt):
    # Normalize spaces
    stmt = stmt.replace('\n', ' ').strip()
    
    # Skip deleted or defaulted functions
    # Matches strings ending in "= delete" or "= default"
    if re.search(r'=\s*(?:delete|default)\s*$', stmt):
        return None

    # Skip Pure Virtual functions
    # Logic: It is pure virtual ONLY if it ends with "= 0" AND contains parentheses "()"
    # This prevents skipping variables like "static const int MAX = 0;"
    # or functions like "void foo(int a = 0)" (which end in parenthesis, not 0)
    if stmt.endswith("= 0") or re.search(r'=\s*0\s*$', stmt):
        if "(" in stmt and ")" in stmt:
            return None
            
    # Clean keywords that might confuse the regex, BUT keep 'static' for now
    # to detect static variables, then we remove it later.
    keywords = [
        "public:", "protected:", "private:", 
        "virtual", "inline", "explicit", "friend", "override", "final"
    ]
    
    for kw in keywords:
        stmt = stmt.replace(kw, "")
        
    stmt = re.sub(r'\s+', ' ', stmt).strip()
    return stmt

# Tokenizer Parser
def parse_header_tokens(text):
    tokens = re.split(r'([{};])', text)
    definitions = []
    
    current_class = None
    depth = 0
    class_depth = -1 
    
    def get_prev_statement_tokens(idx):
        parts = []
        for j in range(idx - 1, -1, -1):
            t = tokens[j]
            if t in ('{', '}', ';'): 
                break
            parts.insert(0, t)
        return "".join(parts)

    for i, token in enumerate(tokens):
        if token == '{':
            prev_text = get_prev_statement_tokens(i).replace('\n', ' ')
            class_match = CLASS_REGEX.search(prev_text)
            if class_match and "enum" not in prev_text:
                current_class = class_match.group(1)
                class_depth = depth
            depth += 1
            
        elif token == '}':
            depth -= 1
            if current_class and depth == class_depth:
                current_class = None
                class_depth = -1
                
        elif token == ';':
            if current_class:
                raw_stmt = get_prev_statement_tokens(i)
                stmt = clean_statement(raw_stmt)
                
                if not stmt: continue 
                
                # Static Variables (Check BEFORE removing static keyword)
                if "static" in stmt and "(" not in stmt:
                     # Remove static for regex match
                     clean_static = stmt.replace("static", "").strip()
                     # Split by last space to get type and name
                     parts = clean_static.rsplit(' ', 1)
                     if len(parts) == 2:
                         var_type = parts[0].strip()
                         var_name = parts[1].strip()
                         definitions.append(('static_var', current_class, var_type, var_name))
                     continue

                # Remove static for methods/ctors
                stmt = stmt.replace("static", "").strip()

                # Constructor
                ctor_match = CTOR_REGEX.search(stmt)
                if ctor_match and ctor_match.group(1) == current_class:
                    definitions.append(('ctor', current_class, ctor_match.group(2)))
                    continue
                
                # Destructor
                dtor_match = DTOR_REGEX.search(stmt)
                if dtor_match and dtor_match.group(1) == current_class:
                    definitions.append(('dtor', current_class))
                    continue

                # Method
                if "(" in stmt and ")" in stmt:
                    m_match = METHOD_REGEX.search(stmt)
                    if m_match:
                        ret = m_match.group(1).strip()
                        name = m_match.group(2).strip()
                        args = m_match.group(3)
                        suffix = m_match.group(4)
                        
                        if name == current_class: continue
                        
                        is_const = "const" in suffix
                        definitions.append(('method', current_class, ret, name, args, is_const))

    return definitions

# Output Generation
if OUTPUT_DIR.exists():
    shutil.rmtree(OUTPUT_DIR)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

generated_count = 0
print(f"Generating {STUB_BACKEND} stubs from: {SOURCE_DIR}")

for header in sorted(SOURCE_DIR.glob("*.h")):
    raw_text = header.read_text()
    clean_text = remove_comments(raw_text)
    
    defs = parse_header_tokens(clean_text)
    if not defs: continue

    stub_path = OUTPUT_DIR / f"{header.stem}{STUB_SUFFIX}"
    with open(stub_path, "w") as f:
        f.write(f"// AUTO-GENERATED STUB FOR {STUB_BACKEND} — DO NOT EDIT\n")
        f.write(f"// Source: {header.name}\n\n")
        f.write(f'#include "Platform/{STUB_BACKEND}/{header.name}"\n')
        f.write(f'#include "{ASSERT_HEADER}"\n\n')
        f.write("namespace Crimson {\n\n")
        
        seen = set()

        for item in defs:
            type_tag = item[0]
            cls = item[1]
            
            if type_tag == 'static_var':
                var_type, var_name = item[2], item[3]
                # Static var definition: Type Class::Name;
                f.write(f"{var_type} {cls}::{var_name};\n\n")

            elif type_tag == 'ctor':
                args = item[2]
                clean_args = strip_default_args(args)
                sig = f"{cls}::{cls}::{clean_args}"
                if sig in seen: continue
                seen.add(sig)

                f.write(f"{cls}::{cls}({clean_args})\n{{\n")
                f.write(f'    CN_CORE_ASSERT(false, "{STUB_BACKEND} backend is not available!");\n}}\n\n')

            elif type_tag == 'dtor':
                sig = f"{cls}::~{cls}"
                if sig in seen: continue
                seen.add(sig)
                f.write(f"{cls}::~{cls}()\n{{\n}}\n\n")

            elif type_tag == 'method':
                ret, name, args, is_const = item[2], item[3], item[4], item[5]
                clean_args = strip_default_args(args)
                qualifier = " const" if is_const else ""
                
                sig = f"{cls}::{name}::{clean_args}::{qualifier}"
                if sig in seen: continue
                seen.add(sig)

                f.write(f"{ret} {cls}::{name}({clean_args}){qualifier}\n{{\n")
                f.write(f'    CN_CORE_ASSERT(false, "{STUB_BACKEND} backend is not available!");\n')
                
                val = default_return_value(ret)
                if val: f.write(f"    return {val};\n")
                f.write("}\n\n")

        f.write("} // namespace Crimson\n")
    
    generated_count += 1

print(f"Successfully generated {generated_count} stub files in {OUTPUT_DIR.relative_to(ROOT)}")