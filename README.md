## Local embedd python installer
 
Установщик embed-Python со списком Packages из requirements.txt.  
Формат requirements.txt стандартный для Python. Файл должен находится рядом со скриптом.    
Скрипт парсит [..python.org/ftp/python/](https://www.python.org/ftp/python/) на предмет наличия embed версий python,
выводит список найденных версий для выбора пользователем, далее выводит список архитектур для выбора пользователем.  
После выбора устанавливает python, pip  и список packages из requirements.txt.
