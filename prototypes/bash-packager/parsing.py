import os
import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--d", required=True) #makes sure directory we want to crawl through is provided
parser.add_argument("--b", nargs="+") #blacklist function, nargs allows multiple items in a list
parser.add_argument("--w", nargs="+") #whitelist
args = parser.parse_args()

for root, dirs, files in os.walk(args.d):
    for f in files:
        '''blacklist: evreything but specified files or endings will not being the tar.
        for example, if .txt was added as a argument for the blacklist, there will be no
        txt files in the tar. Can also put in filenames(with the file type: filename + .csv, 
        .txt, etc) as arguments'''
        if args.b and any(f.endswith(i) for i in args.b):
            continue

        '''whitelist: unlike blacklist, everything will be excluded from the tar except
        the endings/filenames included in the argument'''
        if args.w and not any(f.endswith(i) for i in args.w):
            continue
        
        path = os.path.relpath(os.path.join(root, f), args.d).replace('\\', '/')
        sys.stdout.write(path + '\n')
