#!/usr/bin/env python
import re
import random
import os

def tamper(payload, **kwargs):
    
    retVal = payload
    
    def hexlify(inp): 				# convert string to hex represenatation
        result = "0x"
        for c in inp:
            result += "%02X00" % ord(c)
            
        return result
    
    retVal = retVal.replace('_SYMB_',u'\u00A0') # replace _SYMB_ placeholder with UNICODE space

    m = re.search(r"_DEC_(\d+)__DEC_",retVal)	# decrement row number if needed
    if m:
	retVal = re.sub(m.group(0), str(int(m.group(1))-1), retVal)

    for i in range(1,10):			# repeat values(table names, column names, etc.) in quiery
	m = re.search(r"_REPEAT%d_(.+)__REPEAT%d_" % (i,i),retVal)

	if not m:
		break

	retVal = re.sub(m.group(0), m.group(1), retVal)
	retVal = re.sub("_REPEAT%d_" % i, m.group(1), retVal)

    
    if retVal.find('_ROW_') != -1:		# replace _ROW_ placeholder with row number to extract
    	row = int(os.getenv('_ROWNUM_', '1')) - 1
    	retVal = retVal.replace("_ROW_", str(row))
    
    while(True):				# replace quoted string with HEX representation
	m = re.search(r"'([^']+?)'",retVal)	
	if not m:
		break
	start = m.start()
	end   = m.end()
	val   = m.group(1)
        x = val
	if (val.rfind(".")) != -1:
		x = val[val.rfind(".")+1: ]

        retVal = retVal[0:start] + hexlify(x) + retVal[start + len(val) + 2 : ]
	
    retVal = retVal.replace('_QUOTE_',"'") 	# replace _QUOTE_ placeholder with '
    
    return retVal