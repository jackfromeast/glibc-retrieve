# glibc-retrieve

This is a simple bash script to help retrieve the glibc and ld binaries from the given Dockerfile to facilitate your exploitation in CTFs.

### Installment 
To enhance usability, it is recommended to create a symbolic link or move this script to your /usr/bin directory. Doing so allows you to execute glibc-retrieve from any location in the terminal.

```
sudo ln -s /download/path/to/glibc-retrieve /usr/bin/glibc-retrieve
or
sudo mv /download/path/to/glibc-retrieve /usr/bin/glibc-retrieve
```

### Usage
```
sudo glibc-retrieve /path/to/Dockerfile /path/to/output
```

![example](https://github.com/jackfromeast/glibc-retrieve/blob/main/glibc-retrieve.png)
