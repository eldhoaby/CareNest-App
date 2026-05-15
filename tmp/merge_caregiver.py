import os

def merge_files():
    parts = [
        r'd:\aal_app\tmp\part1.dart',
        r'd:\aal_app\tmp\part2.dart',
        r'd:\aal_app\tmp\part3.dart'
    ]
    
    out_file = r'd:\aal_app\lib\screens\caregiver\caregiver_home_tab.dart'
    
    with open(out_file, 'w', encoding='utf-8') as outfile:
        for part in parts:
            with open(part, 'r', encoding='utf-8') as infile:
                outfile.write(infile.read())
                outfile.write('\n')

if __name__ == '__main__':
    merge_files()
    print("Files merged successfully.")
