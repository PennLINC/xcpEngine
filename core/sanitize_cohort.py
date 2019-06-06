from __future__ import print_function
import sys, os

cohort_file = sys.argv[1]

if not os.path.exists(cohort_file):
    print("Can't open cohort file:", cohort_file)
    sys.exit(1)
