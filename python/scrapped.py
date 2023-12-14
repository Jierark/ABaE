# import subprocess
# import os
# import signal
# import time
# import platform
# import atexit

# # List to hold subprocesses (terminal Popen objects)
# subprocesses = []
# # Function to terminate subprocesses
# def find_cmd_terminals():
#     # Command to list processes and filter by a specific name (e.g., cmd for Command Prompt)
#     command = 'tasklist /V /FI "IMAGENAME eq cmd.exe" /FO CSV | findstr /I /C:"cmd.exe"'

#     # Execute the command using subprocess and capture the output
#     result = subprocess.run(command, shell=True, capture_output=True, text=True)

#     process_pids = []
#     # Extract process PIDs from the output
#     output_lines = result.stdout.splitlines()
#     if len(output_lines) > 1:  # Skip header line
#         process_pids = [line.split(',')[1].strip('"') for line in output_lines[1:]]

#     print("Process PIDs:", process_pids)
#     return process_pids

# def kill_subprocesses():
#     if platform.system() == 'Windows':
#         # Filter and terminate processes based on window title or other criteria
#         for proc in subprocesses:
#             proc.terminate()  # Attempt graceful termination
#             try:
#                 proc.wait(timeout=5)  # Wait for process to terminate
#             except subprocess.TimeoutExpired:
#                 # If the process didn't terminate gracefully, try using taskkill with window title filtering
#                 try:
#                     subprocess.run(['taskkill', '/F', '/FI', f'WINDOWTITLE eq {proc.args[2]}'], shell=True)
#                 except Exception as e:
#                     print(f"Error: {e}")

# subprocesses.append(subprocess.Popen(['start', 'cmd','/K', 'title', 'reader', '&&', 'python', 'test.py'], shell=True))
# subprocesses.append(subprocess.Popen(['start', 'cmd','/K', 'title', 'writer', '&&', 'python', 'test.py'], shell=True))

# atexit.register(kill_subprocesses)

# signal.signal(signal.SIGINT, lambda signum, frame: kill_subprocesses())
# signal.signal(signal.SIGTERM, lambda signum, frame: kill_subprocesses())

# time.sleep(2)
# kill_subprocesses()

# quit()