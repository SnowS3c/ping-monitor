# Ping Monitor
This script continuously checks connectivity to multiple machines on the network..

The script will get the IP address of each MAC from the interace passed as the first parameter.

It will use a global variable ```log_file``` with the path of a log file where to save the events.

For each IP address obtained it will execute a ping, and will check if the ping is correct or not.
In case of incorrect ping, it will enter error mode, show in red the fail and save in the log file the date start of the error. If it takes 30 pings without error, it will exit error mode and write to the log file the end of the fail.

## Usage
* The Enter and Q keys will close the script.
* The L key displays the log file while the ping continues in the background. Inside the view file press Q to exit.

### Example
```bash
./ping-monitor.sh interface macs

./ping-monitor.sh enp2s0 15:32:27:d2:bd:bc 04:40:57:35:bf:e6
```

### Dependences
* arp-scan
* tmux
* tput

## View of the execution
![ping-session1](https://user-images.githubusercontent.com/73076414/126896563-e54d0636-2918-4dc9-9203-1d9f2487a25a.png)
![ping-session22](https://user-images.githubusercontent.com/73076414/126897372-c7cc8a9c-28af-40d5-99fc-557c2762e79d.png)


## View of the log file
![ping-session_log-file](https://user-images.githubusercontent.com/73076414/126896538-58170710-2ad1-4ad5-8729-fb8081162d06.png)

## License
License is [GPLv3](LICENSE)
