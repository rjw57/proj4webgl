#!/usr/bin/env python3
"""
Compile a set of files from the command line into a single JSON file
containing the file contents as a Base64-encoded string.
"""

import base64
import json
import sys

def main():
    """Main entry point for program."""

    # encode all of the input files into one dictionary
    output_dict = {}
    for filename in sys.argv[1:]:
        try:
            encoded_repr = json.load(open(filename, 'r'))
        except ValueError:
            encoded_repr = base64.b64encode(
                    open(filename, 'rb').read()).decode('UTF8')
        output_dict[filename] = encoded_repr

    # output the dict
    json.dump(output_dict, sys.stdout)

if __name__ == '__main__':
    main()

# vim:sw=4:sts=4:et
