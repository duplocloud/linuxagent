import subprocess
retVal = ''
try:
	retVal = subprocess.check_output(["sudo", "ip", "link", "set", "dev", "docker0", "down"])
except subprocess.CalledProcessError as e:
	if e.returncode == 1: 
		print 'Looks like docker0 does not exist'
	else:
		raise

try:
        retVal = subprocess.check_output(["sudo", "brctl", "delbr", "docker0"])
except subprocess.CalledProcessError as e:
        if e.returncode == 1:
                print 'Looks like docker0 does not exist'
        else:

                raise

try:
        retVal = subprocess.check_output(["sudo", "brctl", "addbr", "bridge0"])
except subprocess.CalledProcessError as e:
        if e.returncode == 1:
                print 'Looks like docker0 does not exist'
        else:

                raise

subprocess.check_output(["sudo","ip","addr","flush","dev","bridge0"])
subprocess.check_output(["sudo","ip","addr","add","1.1.1.1/24","dev","bridge0"])
subprocess.check_output(["sudo","ip","link","set","dev","bridge0","up"])
subprocess.check_output(["sudo", "service", "docker", "restart"])

print 'Container Management Setup Succeeded'


