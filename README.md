Логика работы сервиса.

В deployment переменными указываются адреса и порт кластеров postgres
```
- name: POSTGRES_HOST1
  value: postgres-test1.blps-ekb99-manual.svc.cluster.local
- name: POSTGRES_HOST2
  value: postgres-test2.blps-ekb99-manual.svc.cluster.local
- name: POSTGRES_HOST3
  value: postgres-test3.blps-ekb99-manual.svc.cluster.local
- name: POSTGRES_PORT1
  value: "5432"
- name: POSTGRES_PORT2
  value: "5432"
- name: POSTGRES_PORT3
  value: "5432"

```

Далее скрипт, используя адреса POSTGRES_HOST2, POSTGRES_HOST3 и regex templates из POSTGRES_HOST2_DB_LIST, POSTGRES_HOST3_DB_LIST создает 2 списка с указанными в regex переменных базами
 и их владельцами имеющимися на POSTGRES_HOST2 и POSTGRES_HOST3.
После этого по каждому из списков проходится скрипт и создает блоки кода отвечающие за маршрутизацию и вносит их в основной конфигурационный файл odyssey.conf.
Все базы с названием или владельцем postgres игнорируются.
Пользователи не попавшие не в один из списков будут смаршрутизированы на default маршрут. В нашем случае это кластер с адресом в переменной POSTGRES_HOST1.

Нюансы

Если в values.yaml не указаны переменные POSTGRES_HOST2_DB_LIST и POSTGRES_HOST3_DB_LIST, то все маршруты будут направлены на POSTGRES_HOST1. 
Учетная запись, указываемая в secret для deployment, должна быть одинаковой на всех трех кластерах. Лучше всего создать для этого отдельную учетку на всех трех кластерах и указать ее в секрете zif-yandex-odyssey.
Для изменения количества кластеров postgres образ нужно будет пересобирать. Сейчас образ настроен на использование трех кластеров.

Дебаг

После запуска сервиса нужно перейти в терминал контейнера и командами cat или less проверить следующие файлы.

```
cat /etc/odyssey/psql02_list.txt
cat /etc/odyssey/psql03_list.txt
cat /etc/odyssey/odyssey.conf

```
psql02_list.txt - содержит список имен баз и их владельцев, которые удалось найти с применением regexp указанным в переменной POSTGRES_HOST2_DB_LIST
psql02_list.txt - содержит список имен баз и их владельцев, которые удалось найти с применением regexp указанным в переменной POSTGRES_HOST3_DB_LIST
/etc/odyssey/odyssey.conf - в конец файла должны быть добавлены маршруты для списков баз содержащихся в psql02_list.txt и psql03_list.txt

Если файлы или записи в них отсутствуют - значит необходимо проверить синтаксис значений добавленных в переменные POSTGRES_HOST2_DB_LIST, POSTGRES_HOST3_DB_LIST или наличие баз на искомых postgres кластерах.


Мониторинга состояния

Подключение к локальной базе yandex-odyssey
```
psql -h localhost -d console
```

Команды для мониторинга

```
show pools;
show stats;
show clients;
show databases;
show servers;
```
