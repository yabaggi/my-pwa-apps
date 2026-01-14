#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EPUB Unzipper for MyBooks Reader
Extracts EPUB files and creates an index 
for the web reader.
Handles Arabic/Unicode characters and various
 EPUB structures.
"""

import os
import zipfile
import json
import shutil
import xml.etree.ElementTree as ET
import re

MYBOOKS_FOLDER = "mybooks"
UNZIPPED_FOLDER = "unzipped_books"

def get_rootfile_from_container(container_path):
    """Extract the rootfile path from META-INF/container.xml."""
    try:
        tree = ET.parse(container_path)
        root = tree.getroot()
        
        # Define namespaces
        namespaces = {
            'container': 'urn:oasis:names:tc:opendocument:xmlns:container'
        }
        
        # Find rootfile element with namespace
        rootfile = root.find('.//container:rootfile', namespaces)
        if rootfile is not None:
            full_path = rootfile.get('full-path')
            if full_path:
                print(f"      ✓ Found rootfile: {full_path}")
                return full_path
            
        # Fallback without namespace
        for elem in root.iter():
            if 'rootfile' in elem.tag.lower():
                full_path = elem.get('full-path')
                if full_path:
                    print(f"      ✓ Found rootfile (no ns): {full_path}")
                    return full_path
                    
    except Exception as e:
        print(f"      ⚠ Error parsing container.xml: {e}")
        
    return None

def find_spine_items(opf_path):
    """Parse OPF file to get ordered list of content files from spine."""
    try:
        tree = ET.parse(opf_path)
        root = tree.getroot()
        
        # Get namespace if present
        namespace = ''
        if '}' in root.tag:
            namespace = root.tag.split('}')[0] + '}'
        
        # Build manifest dict (id -> href)
        manifest = {}
        for item in root.findall('.//{0}item'.format(namespace)):
            item_id = item.get('id')
            href = item.get('href')
            media_type = item.get('media-type', '')
            
            # Only include XHTML/HTML content
            if item_id and href and ('xhtml' in media_type or 'html' in media_type or 
                                    href.endswith('.xhtml') or href.endswith('.html') or href.endswith('.htm')):
                manifest[item_id] = href
        
        # Get spine order
        spine_items = []
        for itemref in root.findall('.//{0}itemref'.format(namespace)):
            idref = itemref.get('idref')
            if idref and idref in manifest:
                spine_items.append(manifest[idref])
        
        if spine_items:
            print(f"      ✓ Found {len(spine_items)} content files in spine")
        
        return spine_items
        
    except Exception as e:
        print(f"      ⚠ Error parsing OPF: {e}")
        return []

def find_first_content_file(book_folder, opf_path):
    """Find the first content file from the spine."""
    spine_items = find_spine_items(opf_path)
    
    if spine_items:
        # Get directory of OPF file
        opf_dir = os.path.dirname(opf_path)
        
        # Try to find the first content file
        for item in spine_items:
            # Construct full path
            content_path = os.path.normpath(os.path.join(opf_dir, item))
            
            if os.path.exists(content_path):
                # Return path relative to book folder
                rel_path = os.path.relpath(content_path, book_folder)
                # Normalize path separators for web (forward slashes)
                rel_path = rel_path.replace('\\', '/')
                print(f"      ✓ First content file: {rel_path}")
                return rel_path
            else:
                print(f"      ⚠ Content file not found: {content_path}")
    
    return None

def scan_folder_structure(book_folder):
    """Scan the unzipped EPUB folder and determine the content structure."""
    result = {
        'has_container': False,
        'container_path': None,
        'opf_path': None,
        'first_content': None,
        'structure': 'unknown'
    }
    
    print(f"   📂 Scanning folder structure...")
    
    # Check for META-INF/container.xml
    container_path = os.path.join(book_folder, 'META-INF', 'container.xml')
    if os.path.exists(container_path):
        result['has_container'] = True
        result['container_path'] = container_path
        print(f"      ✓ Found META-INF/container.xml")
        
        # Get OPF path from container
        opf_relative = get_rootfile_from_container(container_path)
        if opf_relative:
            opf_full = os.path.join(book_folder, opf_relative)
            if os.path.exists(opf_full):
                result['opf_path'] = opf_full
                print(f"      ✓ Found OPF file")
                
                # Get first content file from spine
                first_content = find_first_content_file(book_folder, opf_full)
                if first_content:
                    result['first_content'] = first_content
                    result['structure'] = 'valid_epub'
                    return result
            else:
                print(f"      ⚠ OPF file not found at: {opf_full}")
    else:
        print(f"      ⚠ No META-INF/container.xml found")
    
    # Fallback 1: Search for any OPF file
    print(f"      🔍 Searching for OPF file...")
    for root, dirs, files in os.walk(book_folder):
        for file in files:
            if file.endswith('.opf'):
                opf_path = os.path.join(root, file)
                result['opf_path'] = opf_path
                print(f"      ✓ Found OPF: {os.path.relpath(opf_path, book_folder)}")
                
                # Get first content from this OPF
                first_content = find_first_content_file(book_folder, opf_path)
                if first_content:
                    result['first_content'] = first_content
                    result['structure'] = 'found_opf'
                    return result
    
    # Fallback 2: Find any HTML/XHTML file
    print(f"      🔍 Searching for HTML/XHTML files...")
    html_files = []
    for root, dirs, files in os.walk(book_folder):
        for file in files:
            if file.endswith(('.xhtml', '.html', '.htm')):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, book_folder)
                rel_path = rel_path.replace('\\', '/')
                html_files.append(rel_path)
    
    if html_files:
        # Sort to get a reasonable first file
        html_files.sort()
        result['first_content'] = html_files[0]
        result['structure'] = 'fallback_html'
        print(f"      ⚠ Using fallback HTML: {html_files[0]}")
        return result
    
    print(f"      ✗ No content files found!")
    return result

def unzip_epub(epub_path, output_folder):
    """Extract an EPUB file to a folder."""
    try:
        with zipfile.ZipFile(epub_path, 'r') as zip_ref:
            zip_ref.extractall(output_folder)
        return True
    except Exception as e:
        print(f"      ✗ Extraction error: {e}")
        return False

def find_epub_files(folder):
    """Find all EPUB files in the given folder."""
    epub_files = []
    
    if not os.path.exists(folder):
        print(f"⚠️  Folder '{folder}' not found. Creating it...")
        os.makedirs(folder)
        return epub_files
    
    for filename in sorted(os.listdir(folder)):
        if filename.lower().endswith('.epub'):
            filepath = os.path.join(folder, filename)
            if os.path.isfile(filepath):
                epub_files.append(filepath)
    
    return epub_files

def create_safe_name(filename):
    """Create a safe folder name from filename."""
    # Remove .epub extension
    name = os.path.splitext(filename)[0]
    
    # Keep alphanumeric, spaces, hyphens, underscores, parentheses
    safe_chars = []
    for char in name:
        if char.isalnum() or char in ' -_()[]':
            safe_chars.append(char)
        else:
            safe_chars.append('_')
    
    safe_name = ''.join(safe_chars).strip()
    
    # Replace multiple spaces/underscores with single underscore
    safe_name = re.sub(r'[_\s]+', '_', safe_name)
    
    # Remove leading/trailing underscores
    safe_name = safe_name.strip('_')
    
    # Limit length
    safe_name = safe_name[:50]
    
    # If empty, use hash
    if not safe_name:
        safe_name = 'book_' + str(abs(hash(filename)))[:8]
    
    return safe_name

def print_header():
    """Print a nice header."""
    print()
    print("=" * 70)
    print("📚 EPUB Unzipper for MyBooks Reader")
    print("   Extracts EPUB files and creates index for web reader")
    print("=" * 70)
    print()

def print_summary(books_info, total_files):
    """Print summary of extraction."""
    print()
    print("=" * 70)
    print("📊 EXTRACTION SUMMARY")
    print("=" * 70)
    
    valid_books = [b for b in books_info if b.get('content_path')]
    error_books = [b for b in books_info if not b.get('content_path')]
    
    print(f"✅ Successfully processed: {len(valid_books)}/{total_files} books")
    if error_books:
        print(f"⚠️  Books with errors: {len(error_books)}")
    
    print(f"📁 Output folder: {os.path.abspath(UNZIPPED_FOLDER)}")
    print(f"📄 Index file: {os.path.abspath('unzipped_books.json')}")
    print("=" * 70)
    
    if books_info:
        print()
        print("📋 BOOKS CATALOG:")
        print("-" * 70)
        for i, book in enumerate(books_info, 1):
            status = "✓" if book.get('content_path') else "✗"
            print(f"\n{status} [{i}] {book['name']}")
            print(f"    Folder: {book.get('folder', 'N/A')}")
            print(f"    Content: {book.get('content_path', 'NOT FOUND')}")
            print(f"    Structure: {book.get('structure', 'unknown')}")
    
    print()
    print("=" * 70)
    if valid_books:
        print("✅ SUCCESS! You can now open index.html in your browser")
    else:
        print("⚠️  No valid books found. Check your EPUB files.")
    print("=" * 70)
    print()

def main():
    print_header()
    
    # Clean existing output
    if os.path.exists(UNZIPPED_FOLDER):
        print(f"🧹 Cleaning existing output folder...")
        shutil.rmtree(UNZIPPED_FOLDER)
    
    os.makedirs(UNZIPPED_FOLDER, exist_ok=True)
    
    # Find EPUB files
    print(f"🔍 Searching for EPUB files in '{MYBOOKS_FOLDER}'...")
    epub_files = find_epub_files(MYBOOKS_FOLDER)
    
    if not epub_files:
        print()
        print("=" * 70)
        print("⚠️  NO EPUB FILES FOUND!")
        print("=" * 70)
        print(f"Please add EPUB files to: {os.path.abspath(MYBOOKS_FOLDER)}")
        print()
        
        # Create empty JSON file
        with open('unzipped_books.json', 'w', encoding='utf-8') as f:
            json.dump([], f, indent=2, ensure_ascii=False)
        
        print("Created empty unzipped_books.json")
        return
    
    print(f"✓ Found {len(epub_files)} EPUB file(s)")
    print()
    
    books_info = []
    
    # Process each EPUB
    for i, epub_path in enumerate(epub_files, 1):
        epub_name = os.path.basename(epub_path)
        safe_name = create_safe_name(epub_name)
        book_folder = os.path.join(UNZIPPED_FOLDER, safe_name)
        
        print(f"[{i}/{len(epub_files)}] Processing: {epub_name}")
        print(f"   → Folder: {safe_name}")
        
        # Remove existing folder if it exists
        if os.path.exists(book_folder):
            shutil.rmtree(book_folder)
        
        # Extract EPUB
        print(f"   📦 Extracting...", end=" ", flush=True)
        
        if unzip_epub(epub_path, book_folder):
            print("✓ Done")
            
            # Analyze structure
            structure = scan_folder_structure(book_folder)
            
            if structure['first_content']:
                book_info = {
                    "name": os.path.splitext(epub_name)[0],
                    "folder": safe_name,
                    "content_path": structure['first_content'],
                    "structure": structure['structure']
                }
                
                books_info.append(book_info)
                print(f"   ✅ Successfully processed!")
            else:
                print(f"   ❌ ERROR: Could not find content files!")
                
                # Show folder contents for debugging
                print(f"   📂 Folder contents:")
                for root, dirs, files in os.walk(book_folder):
                    level = root.replace(book_folder, '').count(os.sep)
                    indent = '   ' + '  ' * level
                    print(f"{indent}📁 {os.path.basename(root)}/")
                    subindent = '   ' + '  ' * (level + 1)
                    for file in files[:3]:  # Show first 3 files per directory
                        print(f"{subindent}📄 {file}")
                    if len(files) > 3:
                        print(f"{subindent}   ... and {len(files) - 3} more files")
                
                # Still add it with empty path
                books_info.append({
                    "name": os.path.splitext(epub_name)[0],
                    "folder": safe_name,
                    "content_path": "",
                    "structure": "error"
                })
        else:
            print("✗ Failed to extract")
            
            # Add error entry
            books_info.append({
                "name": os.path.splitext(epub_name)[0],
                "folder": safe_name,
                "content_path": "",
                "structure": "extraction_error"
            })
        
        print()
    
    # Save JSON index
    print("💾 Saving index file...")
    with open('unzipped_books.json', 'w', encoding='utf-8') as f:
        json.dump(books_info, f, indent=2, ensure_ascii=False)
    print("✓ Index saved")
    
    # Print summary
    print_summary(books_info, len(epub_files))

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Operation cancelled by user")
    except Exception as e:
        print(f"\n\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
