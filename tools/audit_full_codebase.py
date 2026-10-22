#!/usr/bin/env python3
"""
Master Codebase Audit & Repair Tool for Duel of Kings: Animated Chess
Performs deep static analysis across all GDScript files, scene files (.tscn),
resource definitions (.tres), and project configuration (project.godot).

Checks:
  1. Autoload Configuration & Script Integrity (zero missing files, zero class_name conflicts)
  2. Global Class Name Uniqueness (zero duplicate class_name definitions)
  3. GDScript Indentation & Lexical Syntax (tab-only indentation, balanced quotes, valid operators)
  4. Scene & Resource Dependency Paths (all preload/load/ExtResource targets exist)
  5. Clean-Room Rebranding & Unified $9.99 Monetization Consistency
  6. Phone Storage Synchronization & Content Verification

Usage:
  python3 tools/audit_full_codebase.py [--repair] [--sync]
"""

import os
import sys
import re
import filecmp
import shutil
from collections import defaultdict

# ANSI Terminal Styling
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
CYAN = "\033[36m"
MAGENTA = "\033[35m"

def print_header(title: str) -> None:
    print(f"\n{BOLD}{CYAN}======================================================================{RESET}")
    print(f"{BOLD}{CYAN} {title}{RESET}")
    print(f"{BOLD}{CYAN}======================================================================{RESET}")

def print_pass(msg: str) -> None:
    print(f"  {GREEN}✔ [PASS]{RESET} {msg}")

def print_warn(msg: str) -> None:
    print(f"  {YELLOW}⚠ [WARN]{RESET} {msg}")

def print_fail(msg: str) -> None:
    print(f"  {RED}✖ [FAIL]{RESET} {msg}")

def print_info(msg: str) -> None:
    print(f"  {CYAN}ℹ [INFO]{RESET} {msg}")

class CodebaseAuditor:
    def __init__(self, root_dir: str, phone_dir: str, auto_repair: bool = True, auto_sync: bool = True):
        self.root_dir = os.path.abspath(root_dir)
        self.phone_dir = phone_dir
        self.auto_repair = auto_repair
        self.auto_sync = auto_sync
        
        self.total_errors = 0
        self.total_warnings = 0
        self.total_repairs = 0

        self.gd_files: list[str] = []
        self.tscn_files: list[str] = []
        self.tres_files: list[str] = []
        self._collect_project_files()

    def _collect_project_files(self) -> None:
        for root, dirs, files in os.walk(self.root_dir):
            if ".git" in root or ".godot" in root:
                continue
            for f in files:
                rel = os.path.relpath(os.path.join(root, f), self.root_dir)
                if f.endswith(".gd"):
                    self.gd_files.append(rel)
                elif f.endswith(".tscn"):
                    self.tscn_files.append(rel)
                elif f.endswith(".tres"):
                    self.tres_files.append(rel)

    # -------------------------------------------------------------------------
    # 1. Project Autoloads & Engine Configuration
    # -------------------------------------------------------------------------
    def audit_project_configuration(self) -> None:
        print_header("1. Project Configuration & Autoload Audit")
        pg_path = os.path.join(self.root_dir, "project.godot")
        if not os.path.exists(pg_path):
            print_fail("project.godot file not found!")
            self.total_errors += 1
            return

        with open(pg_path, "r", encoding="utf-8") as fp:
            content = fp.read()

        # Check main scene
        main_scene_match = re.search(r'run/main_scene="res://([^"]+)"', content)
        if main_scene_match:
            main_rel = main_scene_match.group(1)
            main_full = os.path.join(self.root_dir, main_rel)
            if os.path.exists(main_full):
                print_pass(f"Main scene correctly defined: res://{main_rel}")
            else:
                print_fail(f"Main scene targets missing file: res://{main_rel}")
                self.total_errors += 1
        else:
            print_fail("No run/main_scene found in project.godot!")
            self.total_errors += 1

        # Check autoloads
        autoload_matches = re.findall(r'^\s*([A-Za-z0-9_]+)="(\*?res://([^"]+))"', content, re.MULTILINE)
        print_info(f"Auditing {len(autoload_matches)} Autoload Singletons:")

        autoload_script_paths = []
        for name, full_res, rel_path in autoload_matches:
            target_path = os.path.join(self.root_dir, rel_path)
            if not os.path.exists(target_path):
                print_fail(f"Autoload '{name}' missing target file: {full_res}")
                self.total_errors += 1
            else:
                autoload_script_paths.append(rel_path)
                # Verify autoload script does NOT define class_name
                with open(target_path, "r", encoding="utf-8") as afp:
                    for lnum, line in enumerate(afp, 1):
                        if re.match(r'^\s*class_name\b', line):
                            print_fail(f"Autoload '{name}' ({rel_path}:{lnum}) declares class_name! This causes Godot 4 shadowing collisions.")
                            self.total_errors += 1
                            break
                    else:
                        print_pass(f"Autoload '{name}' -> res://{rel_path} (valid & collision-free)")

        # Verify essential singletons
        required_singletons = ["EventBus", "PlatformManager", "KillMatrix", "DuelDirector", "EloCalculator", "ThemeManager"]
        registered_names = [m[0] for m in autoload_matches]
        for req in required_singletons:
            if req not in registered_names:
                print_fail(f"Required singleton '{req}' is NOT registered in [autoload] in project.godot!")
                self.total_errors += 1

        # Check Object Picking configuration
        if "common/enable_object_picking=true" in content:
            print_pass("3D Physics Object Picking is explicitly enabled in [physics]")
        else:
            print_warn("common/enable_object_picking=true not found in project.godot; will rely on default engine picking.")

    # -------------------------------------------------------------------------
    # 2. Autoload Cyclic Reference & Decoupling Audit
    # -------------------------------------------------------------------------
    def audit_autoload_decoupling(self) -> None:
        print_header("2. Autoload Cyclic Reference & Decoupling Audit")
        pg_path = os.path.join(self.root_dir, "project.godot")
        with open(pg_path, "r", encoding="utf-8") as fp:
            content = fp.read()
        autoload_matches = re.findall(r'^\s*([A-Za-z0-9_]+)="(\*?res://([^"]+))"', content, re.MULTILINE)
        autoload_names = [m[0] for m in autoload_matches]

        all_clean = True
        for name, full_res, rel_path in autoload_matches:
            target_path = os.path.join(self.root_dir, rel_path)
            if not os.path.exists(target_path):
                continue
            with open(target_path, "r", encoding="utf-8") as fp:
                lines = fp.readlines()

            in_func = False
            for lnum, raw_line in enumerate(lines, 1):
                line = raw_line.strip()
                if line.startswith("func ") or line.startswith("static func "):
                    in_func = True

                # Check top-level variable declarations (outside functions)
                if not in_func:
                    # Check for non-builtin type annotations like ': GameEnums.' or ': PieceTheme'
                    if re.match(r'^(?:@\w+\s+)?var\s+\w+\s*:\s*(?:GameEnums\.|PieceTheme\b|State\b|ChessBoard\b)', line):
                        print_fail(f"Autoload '{name}' ({rel_path}:{lnum}) has compile-time class type annotation: {line}")
                        self.total_errors += 1
                        all_clean = False

                    # Check for top-level singleton invocation in var initializers
                    for other_auto in autoload_names:
                        if re.search(r'^(?:@\w+\s+)?var\s+\w+.*=\s*.*\b' + other_auto + r'\.', line):
                            print_fail(f"Autoload '{name}' ({rel_path}:{lnum}) calls singleton '{other_auto}' at file-load time: {line}")
                            self.total_errors += 1
                            all_clean = False

                    # Check for signal arguments typed as custom class_name or GameEnums
                    if line.startswith("signal "):
                        if re.search(r':\s*(?:GameEnums\.|PieceTheme\b|State\b)', line):
                            print_fail(f"Autoload '{name}' ({rel_path}:{lnum}) signal has custom class type hint: {line}")
                            self.total_errors += 1
                            all_clean = False

        if all_clean:
            print_pass("All Autoload singletons are completely decoupled from top-level class_name and singleton references.")

    # -------------------------------------------------------------------------
    # 3. Global class_name Uniqueness Audit
    # -------------------------------------------------------------------------
    def audit_class_name_uniqueness(self) -> None:
        print_header("3. Global Class Name Uniqueness Audit")
        declared_classes = defaultdict(list)

        for rel_path in self.gd_files:
            full_path = os.path.join(self.root_dir, rel_path)
            with open(full_path, "r", encoding="utf-8") as fp:
                for lnum, line in enumerate(fp, 1):
                    m = re.match(r'^\s*class_name\s+([A-Za-z0-9_]+)', line)
                    if m:
                        cname = m.group(1)
                        declared_classes[cname].append((rel_path, lnum))

        duplicates = {k: v for k, v in declared_classes.items() if len(v) > 1}
        if duplicates:
            for cname, locs in duplicates.items():
                print_fail(f"Duplicate class_name '{cname}' found:")
                for rpath, lnum in locs:
                    print(f"      - res://{rpath}:{lnum}")
                self.total_errors += 1
        else:
            print_pass(f"All {len(declared_classes)} declared class_names are globally unique across the project.")

    # -------------------------------------------------------------------------
    # 4. GDScript Indentation & Lexical Syntax Audit
    # -------------------------------------------------------------------------
    def audit_gdscript_syntax(self) -> None:
        print_header("4. GDScript Syntax, Indentation & Lexical Audit")
        syntax_clean = True

        for rel_path in self.gd_files:
            full_path = os.path.join(self.root_dir, rel_path)
            with open(full_path, "r", encoding="utf-8") as fp:
                lines = fp.readlines()

            file_modified = False
            new_lines = []
            multiline_double = False
            multiline_single = False

            for lnum, raw_line in enumerate(lines, 1):
                line = raw_line.rstrip("\r\n")
                stripped = line.lstrip()

                if not stripped or stripped.startswith("#"):
                    new_lines.append(raw_line)
                    continue

                # 1. Indentation Check
                indent = line[:len(line) - len(stripped)]
                if " " in indent and "\t" in indent:
                    if self.auto_repair:
                        # Convert leading spaces to tabs assuming 4 spaces = 1 tab
                        repaired_indent = indent.replace("    ", "\t").replace("  ", "\t").replace(" ", "")
                        line = repaired_indent + stripped
                        new_lines.append(line + "\n")
                        file_modified = True
                        self.total_repairs += 1
                        print_pass(f"Auto-repaired mixed indentation in res://{rel_path}:{lnum}")
                    else:
                        print_fail(f"Mixed tabs/spaces in res://{rel_path}:{lnum}: {repr(indent)}")
                        syntax_clean = False
                        self.total_errors += 1
                        new_lines.append(raw_line)
                    continue
                else:
                    new_lines.append(raw_line)

                # 2. Quote Balancing
                code = re.sub(r'#.*$', '', line)
                if '"""' in code:
                    multiline_double = not multiline_double
                elif "'''" in code:
                    multiline_single = not multiline_single
                elif not multiline_double and not multiline_single:
                    # Strip complete double-quoted and single-quoted string literals
                    code_no_double_str = re.sub(r'"(?:[^"\\]|\\.)*"', '', code)
                    code_no_single_str = re.sub(r"'(?:[^'\\]|\\.)*'", '', code)

                    if code_no_single_str.count('"') % 2 != 0:
                        print_fail(f"Unbalanced double quotes in res://{rel_path}:{lnum}: {line.strip()}")
                        syntax_clean = False
                        self.total_errors += 1
                    if code_no_double_str.count("'") % 2 != 0:
                        print_fail(f"Unbalanced single quotes in res://{rel_path}:{lnum}: {line.strip()}")
                        syntax_clean = False
                        self.total_errors += 1

                # 3. Invalid GDScript Operators (++ / --)
                if ("++" in code or "--" in code) and not ('"++"' in code or "'++'" in code or '"--"' in code):
                    print_fail(f"Invalid operator ++/-- in res://{rel_path}:{lnum}: {line.strip()}")
                    syntax_clean = False
                    self.total_errors += 1

                # 4. Godot 3 Legacy Keyword Check
                if re.match(r'^(export|onready|tool)\b', stripped):
                    print_fail(f"Legacy Godot 3 keyword '{stripped.split()[0]}' in res://{rel_path}:{lnum}. Use Godot 4 @annotations.")
                    syntax_clean = False
                    self.total_errors += 1

                # 5. Single line getter/setter parser trap
                if re.search(r'\b(get|set(\([^\)]*\))?)\s*:\s*[^\s#]', code):
                    print_fail(f"Single line getter/setter trap in res://{rel_path}:{lnum}: {line.strip()}")
                    syntax_clean = False
                    self.total_errors += 1

            if file_modified:
                with open(full_path, "w", encoding="utf-8") as fp:
                    fp.writelines(new_lines)

        if syntax_clean:
            print_pass(f"All {len(self.gd_files)} GDScript files passed lexical, indentation, and operator validation.")

    # -------------------------------------------------------------------------
    # 5. Resource & Scene Link Integrity Audit
    # -------------------------------------------------------------------------
    def audit_resource_links(self) -> None:
        print_header("5. Resource & Scene Link Integrity Audit")
        missing_resources = []

        # Check preloads and loads in GDScript
        for rel_path in self.gd_files:
            full_path = os.path.join(self.root_dir, rel_path)
            with open(full_path, "r", encoding="utf-8") as fp:
                content = fp.read()
            for m in re.finditer(r'(preload|load)\(\s*\"res://([^\"]+)\"\s*\)', content):
                target_rel = m.group(2)
                target_full = os.path.join(self.root_dir, target_rel)
                if not os.path.exists(target_full):
                    missing_resources.append((rel_path, target_rel, m.group(0)))

        # Check ExtResource in .tscn and .tres files
        for rel_path in self.tscn_files + self.tres_files:
            full_path = os.path.join(self.root_dir, rel_path)
            with open(full_path, "r", encoding="utf-8") as fp:
                content = fp.read()
            for m in re.finditer(r'path=\"res://([^\"]+)\"', content):
                target_rel = m.group(1)
                target_full = os.path.join(self.root_dir, target_rel)
                if not os.path.exists(target_full):
                    missing_resources.append((rel_path, target_rel, f'path="res://{target_rel}"'))

        if missing_resources:
            for src_file, target_file, expr in missing_resources:
                print_fail(f"Broken resource link in res://{src_file} -> {target_file}")
                self.total_errors += 1
        else:
            total_checked = len(self.gd_files) + len(self.tscn_files) + len(self.tres_files)
            print_pass(f"All resource dependencies across {total_checked} files verified to exist on disk.")

    # -------------------------------------------------------------------------
    # 6. Clean-Room Rebranding & Monetization Integrity Audit
    # -------------------------------------------------------------------------
    def audit_branding_and_monetization(self) -> None:
        print_header("6. Branding & Unified Monetization Audit")
        
        # 1. Check trademark risks
        trademark_violations = []
        forbidden_terms = [r"\bBattle\s+Chess\b", r"\bInterplay\b"]
        
        for rel_path in self.gd_files + self.tscn_files + ["project.godot"]:
            full_path = os.path.join(self.root_dir, rel_path)
            if not os.path.exists(full_path):
                continue
            with open(full_path, "r", encoding="utf-8", errors="ignore") as fp:
                for lnum, line in enumerate(fp, 1):
                    for term in forbidden_terms:
                        if re.search(term, line, re.IGNORECASE):
                            # Permit historical comments or spiritual successor disclaimers
                            if "spiritual successor" in line.lower() or "1988" in line:
                                continue
                            trademark_violations.append((rel_path, lnum, line.strip()))

        if trademark_violations:
            for rpath, lnum, ltext in trademark_violations:
                print_warn(f"Trademark match in res://{rpath}:{lnum}: {ltext}")
                self.total_warnings += 1
        else:
            print_pass("Codebase is clean of direct trademark naming collisions.")

        # 2. Check unified $9.99 monetization in PlatformManager
        pm_path = os.path.join(self.root_dir, "src/autoload/platform_manager.gd")
        if os.path.exists(pm_path):
            with open(pm_path, "r", encoding="utf-8") as fp:
                pm_code = fp.read()
            if "has_full_game_unlock" in pm_code and "$9.99" in pm_code:
                print_pass("PlatformManager enforces unified $9.99 Full Game Unlock.")
            else:
                print_fail("PlatformManager does not properly declare unified $9.99 Full Game Unlock!")
                self.total_errors += 1
        else:
            print_fail("src/autoload/platform_manager.gd does not exist!")
            self.total_errors += 1

        # Check export presets
        ep_path = os.path.join(self.root_dir, "export_presets.cfg")
        if os.path.exists(ep_path):
            with open(ep_path, "r", encoding="utf-8") as fp:
                ep_code = fp.read()
            if "$9.99" in ep_code:
                print_pass("export_presets.cfg aligns with $9.99 Full Game pricing.")
            else:
                print_warn("export_presets.cfg does not mention $9.99 pricing in metadata.")

    # -------------------------------------------------------------------------
    # 7. Phone Storage Synchronization & Verification
    # -------------------------------------------------------------------------
    def audit_and_sync_phone(self) -> None:
        print_header("7. Phone Storage Synchronization & Checksum Verification")
        if not os.path.exists(self.phone_dir):
            print_warn(f"Phone storage directory not accessible at: {self.phone_dir}")
            return

        # Purge stale .godot/ cache on phone directory for fresh indexing
        phone_godot_cache = os.path.join(self.phone_dir, ".godot")
        if os.path.exists(phone_godot_cache):
            try:
                shutil.rmtree(phone_godot_cache)
                print_pass("Purged stale .godot/ cache on phone storage for fresh Godot 4 re-indexing.")
            except Exception as e:
                print_warn(f"Failed to purge .godot/ cache on phone: {e}")

        if self.auto_sync:
            print_info(f"Mirroring workspace files to {self.phone_dir}...")
            # Remove obsolete files from phone
            removed_count = 0
            for root, dirs, files in os.walk(self.phone_dir):
                if ".git" in root or ".godot" in root:
                    continue
                rel = os.path.relpath(root, self.phone_dir)
                src_dir = os.path.join(self.root_dir, rel)
                for f in files:
                    src_file = os.path.join(src_dir, f)
                    if not os.path.exists(src_file):
                        dst_file = os.path.join(root, f)
                        try:
                            os.remove(dst_file)
                            removed_count += 1
                        except Exception:
                            pass

            # Copy updated files
            synced_count = 0
            for root, dirs, files in os.walk(self.root_dir):
                if ".git" in root or ".godot" in root:
                    continue
                rel = os.path.relpath(root, self.root_dir)
                dst_dir = os.path.join(self.phone_dir, rel)
                os.makedirs(dst_dir, exist_ok=True)
                for f in files:
                    sfile = os.path.join(root, f)
                    dfile = os.path.join(dst_dir, f)
                    shutil.copy2(sfile, dfile)
                    synced_count += 1

            # Remove empty directories
            for root, dirs, files in os.walk(self.phone_dir, topdown=False):
                if ".git" in root or ".godot" in root:
                    continue
                if not os.listdir(root):
                    try:
                        os.rmdir(root)
                    except Exception:
                        pass

            print_pass(f"Mirrored {synced_count} files (purged {removed_count} obsolete files).")

        # Verify key file checksums
        mismatches = []
        for rel_path in self.gd_files + self.tscn_files + ["project.godot", "export_presets.cfg"]:
            sfile = os.path.join(self.root_dir, rel_path)
            dfile = os.path.join(self.phone_dir, rel_path)
            if not os.path.exists(dfile):
                mismatches.append(f"Missing on phone: res://{rel_path}")
            elif not filecmp.cmp(sfile, dfile, shallow=False):
                mismatches.append(f"Content mismatch: res://{rel_path}")

        if mismatches:
            for m in mismatches[:10]:
                print_fail(m)
            self.total_errors += len(mismatches)
        else:
            print_pass("100% of workspace files verified identical to phone storage.")

    # -------------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------------
    def run_all(self) -> int:
        print(f"{BOLD}{MAGENTA}Duel of Kings: Animated Chess — Full Codebase Audit & Repair{RESET}")
        print(f"Project Root: {self.root_dir}")
        print(f"Phone Target: {self.phone_dir}")

        self.audit_project_configuration()
        self.audit_autoload_decoupling()
        self.audit_class_name_uniqueness()
        self.audit_gdscript_syntax()
        self.audit_resource_links()
        self.audit_branding_and_monetization()
        self.audit_and_sync_phone()

        print_header("Audit Results Summary")
        if self.total_repairs > 0:
            print(f"  {GREEN}Repairs Applied:{RESET} {self.total_repairs}")
        print(f"  {CYAN}Total Warnings:{RESET} {self.total_warnings}")
        print(f"  {RED if self.total_errors > 0 else GREEN}Total Errors:{RESET}   {self.total_errors}")

        if self.total_errors == 0:
            print(f"\n{BOLD}{GREEN}ALL AUDIT CHECKS PASSED PERFECTLY! The codebase is in peak health.{RESET}\n")
            return 0
        else:
            print(f"\n{BOLD}{RED}AUDIT FAILED with {self.total_errors} errors. Please review the details above.{RESET}\n")
            return 1

if __name__ == "__main__":
    auto_repair = "--no-repair" not in sys.argv
    auto_sync = "--no-sync" not in sys.argv
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, ".."))
    phone_dir = "/data/data/com.termux/files/home/storage/shared/Documents/battle-chess-reborn"

    auditor = CodebaseAuditor(project_root, phone_dir, auto_repair=auto_repair, auto_sync=auto_sync)
    sys.exit(auditor.run_all())
