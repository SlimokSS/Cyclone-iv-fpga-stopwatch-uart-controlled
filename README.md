# UART-Controlled Stopwatch on Cyclone IV FPGA

Цифровой секундомер на FPGA с управлением через UART-интерфейс с компьютера.

Проект принимает текстовые команды через виртуальный COM-порт, управляет состоянием секундомера и по запросу передаёт текущее время обратно на компьютер в ASCII-формате.

Проект разработан на **SystemVerilog** и синтезирован для FPGA **Intel/Altera Cyclone IV E — EP4CE6F17C8N**.

---

## Возможности

Поддерживаются следующие UART-команды:

```text
START
STOP
CLEAR
TIME
```

Назначение команд:

- `START` — запускает секундомер;
- `STOP` — останавливает секундомер;
- `CLEAR` — сбрасывает время;
- `TIME` — возвращает текущее значение секундомера через UART.

Формат ответа на команду `TIME`:

```text
HH:MM:SS.CC
```

Фактически передаваемая строка завершается `CRLF`:

```text
HH:MM:SS.CC\r\n
```

где:

- `HH` — часы;
- `MM` — минуты;
- `SS` — секунды;
- `CC` — сотые доли секунды.

Пример:

```text
START
STOP
TIME

00:00:03.47
```

---

## Параметры проекта

| Параметр | Значение |
|---|---:|
| FPGA | Cyclone IV E EP4CE6F17C8N |
| Тактовая частота | 50 MHz |
| Период системного clock | 20 ns |
| UART baud rate | 115200 baud |
| UART format | 8N1 |
| Разрешение секундомера | 10 ms |
| Частота tick секундомера | 100 Hz |

---

## Архитектура

Верхним модулем проекта является:

```text
uart_command_top
```

Он соединяет все функциональные блоки системы.

Общая структура:

```text
                    PC / COM Port
                         │
                         │ UART RX
                         ▼
                    ┌─────────┐
                    │ uart_rx │
                    └────┬────┘
                         │
                  rx_data/rx_valid
                         │
                         ▼
              ┌────────────────────┐
              │ uart_cmd_parser_v2 │
              └──────┬────────┬────┘
                     │        │
       START/STOP/CLEAR        │ TIME
                     │        │
                     ▼        │
           ┌────────────────┐  │
           │ command_executor│  │
           └───────┬────────┘  │
                   │           │
            running / clear    │
                   │           │
                   ▼           │
           ┌───────────────┐   │
           │ stopwatch_core│   │
           └───────┬───────┘   │
                   │           │
          HH / MM / SS / CC    │
                   │           │
                   └─────┬─────┘
                         ▼
                ┌───────────────────┐
                │ time_response_gen │
                └─────────┬─────────┘
                          │
                    ready / valid
                          │
                          ▼
                     ┌─────────┐
                     │ uart_tx │
                     └────┬────┘
                          │
                          │ UART TX
                          ▼
                    PC / COM Port
```

---

## Описание модулей

### `uart_command_top`

Верхний модуль проекта.

Соединяет UART-приёмник, парсер команд, исполнитель команд, секундомер, генератор ответа и UART-передатчик.

---

### `uart_rx`

UART-приёмник.

Принимает последовательный поток от компьютера и преобразует его в 8-битные байты.

Основные выходные сигналы:

```text
rx_data
rx_valid
```

Асинхронный UART RX input предварительно проходит через двухрегистровый синхронизатор.

2-FF synchronizer не устраняет metastability физически, а даёт первому flip-flop дополнительное время на разрешение метастабильного состояния перед использованием сигнала остальной логикой.

---

### `uart_cmd_parser_v2`

Парсер текстовых команд.

Принимает байты от `uart_rx`, накапливает строку до символа конца строки `CR` или `LF`, после чего распознаёт команду.

Поддерживаются:

```text
START
STOP
CLEAR
TIME
```

Для каждой распознанной команды формируется одноклоковый импульс:

```text
cmd_start
cmd_stop
cmd_clear
cmd_time
```

Также предусмотрена обработка слишком длинных и неизвестных команд.

---

### `command_executor`

Исполняет команды управления секундомером.

Логика работы:

```text
START → running = 1
STOP  → running = 0
CLEAR → clear_pulse = 1 на один clock
```

`running` является состоянием, а `clear_pulse` — одноклоковым событием.

---

### `stopwatch_core`

Основной модуль секундомера.

Хранит:

```text
hours
minutes
seconds
centis
```

Сотые доли секунды увеличиваются по сигналу `tick_10ms`.

Диапазон времени:

```text
00:00:00.00
...
23:59:59.99
```

После `23:59:59.99` счётчик возвращается к:

```text
00:00:00.00
```

---

### `tick_gen`

Формирует временную базу для секундомера.

При системной частоте:

```text
50 MHz
```

генерируется:

```text
100 ticks/s
```

то есть один tick каждые:

```text
10 ms
```

Генератор работает при `running = 1`.

---

## `time_response_gen`

Формирует UART-ответ на команду `TIME`.

При поступлении `cmd_time` модуль сохраняет snapshot текущего времени:

```text
hours
minutes
seconds
centis
```

После snapshot изменение самого секундомера больше не влияет на формируемый ответ.

Строка ответа:

```text
HH:MM:SS.CC\r\n
```

Всего передаётся 13 байт:

```text
0   H tens
1   H ones
2   :
3   M tens
4   M ones
5   :
6   S tens
7   S ones
8   .
9   C tens
10  C ones
11  CR
12  LF
```

### Control path

Текущая версия использует FSM:

```text
IDLE
  │
  │ cmd_time
  ▼
CONVERT
  │
  │ conversion_done
  ▼
SEND
  │
  │ last byte && ready/valid handshake
  ▼
IDLE
```

В `IDLE` выполняется snapshot времени и подготовка datapath.

В `CONVERT` binary-to-decimal преобразование выполняется последовательно по clock cycles.

В `SEND` готовая ASCII-строка передаётся в `uart_tx`.

Команда `TIME`, пришедшая во время `CONVERT` или `SEND`, в текущей архитектуре не ставится в очередь.

### Binary-to-decimal conversion

Первая версия formatter использовала:

```systemverilog
value / 10
value % 10
```

После synthesis Quartus реализовал эти операции как достаточно дорогую комбинационную арифметику.

В текущей версии используется последовательное вычитание:

```text
temp = value
tens = 0

while temp >= 10:
    temp -= 10
    tens++

ones = temp
```

Важно: это не synthesizable software-style `while`, разворачиваемый в большую комбинационную схему.

В RTL выполняется только одно:

```text
compare
subtract 10
increment tens
```

за один clock.

Для четырёх полей:

```text
hours
minutes
seconds
centis
```

используются четыре параллельных subtract datapath.

Например:

```text
99 → 89 → 79 → 69 → 59 → 49 → 39 → 29 → 19 → 9
```

требует 9 subtract cycles.

После этого формируются ASCII-символы:

```systemverilog
8'h30 + digit
```

Таким образом новая архитектура использует trade-off:

```text
combinational area ↓
registers          ↑
conversion latency ↑
timing margin      ↑
```

Для UART увеличение conversion latency практически несущественно.

При 50 MHz один clock составляет:

```text
20 ns
```

а один UART frame при 115200 baud занимает примерно:

```text
10 / 115200 ≈ 86.8 us
```

Даже worst-case binary-to-decimal conversion занимает лишь несколько сотен наносекунд до начала передачи.

---

### `uart_tx`

UART-передатчик.

Получает байты через интерфейс:

```text
s_data
s_valid
s_ready
```

и передаёт их через UART в формате 8N1.

Передатчик поддерживает передачу последовательных UART frames без лишнего системного idle-clock между ними.

---

### `baud_tick_gen`

Формирует baud tick для UART TX.

В проекте используется fractional accumulator / NCO-подобная схема для получения средней baud rate, соответствующей:

```text
115200 baud
```

---

## Ready/Valid интерфейс

Для передачи данных между `time_response_gen` и `uart_tx` используется handshake:

```systemverilog
fire = valid && ready;
```

Данные считаются переданными только в clock cycle, когда одновременно:

```text
valid = 1
ready = 1
```

Если:

```text
valid = 1
ready = 0
```

source обязан удерживать текущий байт стабильным.

В `time_response_gen` индекс следующего символа изменяется только после успешного handshake.

Последний байт — `LF` с индексом `12`.

Переход:

```text
SEND → IDLE
```

выполняется только после handshake последнего байта.

---

## FPGA Pin Assignment

Текущая конфигурация платы:

| Signal | FPGA Pin |
|---|---|
| `clk` | E1 |
| `rst_n` | N13 |
| `uart_rx_pin` | M2 |
| `uart_tx_pin` | N1 |

I/O standard:

```text
3.3-V LVTTL
```

---

## UART Configuration

Настройки терминала:

```text
Baud rate : 115200
Data bits : 8
Parity    : None
Stop bits : 1
Flow ctrl : None
```

Команды вводятся в верхнем регистре.

---

# FPGA Resource Usage

## Divider-based baseline

Первая версия `time_response_gen` использовала:

```systemverilog
/ 10
% 10
```

Результат synthesis для всего проекта:

```text
Total Logic Elements : 559 / 6272 ≈ 9%
Total Registers      : 186
I/O Pins             : 4
Memory Bits          : 0
DSP Blocks           : 0
PLLs                 : 0
```

Приблизительное использование ресурсов самим `time_response_gen`:

```text
Combinational ALUT : ~295
Registers          : ~29
```

Большая часть комбинационной логики была связана с binary-to-decimal divider/modulo logic.

---

## Sequential subtract version

После замены `/10` и `%10` на multi-cycle subtract-by-10 архитектуру:

```text
Total Logic Elements : 404 / 6272 ≈ 6%
Total Registers      : 229
I/O Pins             : 4
Memory Bits          : 0
DSP Blocks           : 0
PLLs                 : 0
```

Для `time_response_gen`:

```text
Combinational ALUT : 133
Registers          : 72
```

Изменение относительно divider-based baseline:

```text
Total Logic Elements:
559 → 404
-155 LE
≈ -27.7%

time_response_gen ALUT:
~295 → 133
-162 ALUT
≈ -54.9%

Total Registers:
186 → 229
+43 registers
```

Таким образом synthesis подтвердил ожидаемый архитектурный trade-off:

```text
AREA ↓
REGISTERS ↑
LATENCY ↑
```

---

## Architecture Comparison

| Метрика | Divider-based | Sequential subtract |
|---|---:|---:|
| Total Logic Elements | 559 | 404 |
| FPGA utilization | ~9% | ~6% |
| Total Registers | 186 | 229 |
| `time_response_gen` ALUT | ~295 | 133 |
| `time_response_gen` Registers | ~29 | 72 |
| Worst Setup Slack | +5.537 ns | +10.466 ns |
| Worst Hold Slack | +0.186 ns | +0.452 ns |
| Conversion style | Combinational | Multi-cycle |
| Arithmetic | `/10`, `%10` | compare / subtract |
| Conversion latency | Low | Higher |
| UART impact | Negligible | Negligible |

Главный результат:

```text
короткий RTL-код != маленькое железо
```

Операции `/10` и `%10` выглядят компактно в SystemVerilog, но могут приводить к значительно более дорогой аппаратной реализации, чем multi-cycle datapath.

---

# Timing

Системная частота:

```text
50 MHz
```

Период:

```text
20 ns
```

Основное SDC-ограничение:

```tcl
create_clock -name clk -period 20.000 [get_ports {clk}]
derive_clock_uncertainty
```

## Divider-based version

После Place & Route:

```text
Worst Setup Slack : +5.537 ns
Worst Hold Slack  : +0.186 ns
```

## Sequential subtract version

После Place & Route:

```text
Worst Setup Slack : +10.466 ns
Worst Hold Slack  : +0.452 ns
```

Улучшение setup margin:

```text
10.466 ns - 5.537 ns = 4.929 ns
```

То есть после изменения архитектуры проект получил примерно:

```text
+4.929 ns
```

дополнительного worst-case setup margin.

Положительные setup и hold slack означают, что проанализированные синхронные пути удовлетворяют заданному clock constraint 50 MHz.

---

## Current Worst Setup Path

Для текущей sequential-версии TimeQuest показывает:

```text
Data Arrival Time  : 12.029 ns
Data Required Time : 22.495 ns
Slack              : 10.466 ns
```

Текущий worst setup path начинается в иерархии:

```text
uart_tx / baud_tick_gen
```

и заканчивается внутри:

```text
time_response_gen
```

Это означает, что после удаления divider-based combinational logic старый formatter больше не является очевидным доминирующим combinational bottleneck.

Важно: `20 ns - slack` нельзя интерпретировать как точную задержку комбинационной логики.

STA учитывает не только data-path logic, но также:

```text
clock paths
setup time
clock skew
clock uncertainty
routing delays
cell delays
```

Для точного анализа используется подробный отчёт TimeQuest `Report Timing`.

---

# Что показал эксперимент

Этот проект использовался как практический пример выбора RTL-архитектуры.

### Version A — combinational division

```systemverilog
tens = value / 10;
ones = value % 10;
```

Плюсы:

- простой RTL;
- минимальная conversion latency.

Минусы:

- высокая стоимость комбинационной логики;
- более длинные timing paths.

### Version B — sequential subtract

```text
compare
subtract 10
increment counter
repeat on next clock
```

Плюсы:

- значительно меньше combinational logic;
- больше timing margin;
- хорошо демонстрирует hardware reuse во времени.

Минусы:

- больше registers;
- требуется FSM/control path;
- conversion занимает несколько clock cycles.

Для данного проекта Version B выгодна, поскольку UART значительно медленнее внутреннего 50 MHz datapath.

---

# Возможные дальнейшие архитектуры

Следующий вариант для исследования — ещё более area-oriented formatter с одним общим converter:

```text
hours
  ↓
shared converter
  ↓
minutes
  ↓
shared converter
  ↓
seconds
  ↓
shared converter
  ↓
centis
```

Такой вариант может переиспользовать:

```text
1 comparator
1 subtractor
1 temporary register
1 tens counter
```

ценой ещё большей conversion latency.

Ещё одна возможная архитектура — хранить время непосредственно в BCD:

```text
hour_tens
hour_ones
minute_tens
minute_ones
second_tens
second_ones
centis_tens
centis_ones
```

Тогда ASCII formatting становится почти бесплатным:

```systemverilog
8'h30 + digit
```

но усложняется datapath самого секундомера.

---

# Дальнейшее развитие

Планируемые этапы:

- анализ новой схемы через RTL Viewer;
- анализ Technology Map Viewer;
- изучение Chip Planner;
- использование SignalTap для отладки;
- более глубокий STA;
- дальнейшее изучение SDC;
- reset architecture;
- CDC и metastability;
- pulse crossing и handshake;
- asynchronous FIFO;
- SPI;
- I2C;
- Avalon / AXI;
- VGA/video logic;
- DSP и pipelining;
- собственный небольшой CPU;
- возможный RISC-V soft-core.

---

## Инструменты

Проект разработан с использованием:

```text
Intel Quartus Prime Lite 21.1 Build 842
SystemVerilog
Cyclone IV E
```

FPGA:

```text
EP4CE6F17C8N
```

Для обмена данными с FPGA используется UART через виртуальный COM-порт.

---

## Статус проекта

Текущая sequential-версия:

```text
UART RX                  — implemented
UART TX                  — implemented
Command parser            — implemented
START                     — implemented
STOP                      — implemented
CLEAR                     — implemented
TIME                      — implemented
Stopwatch core            — implemented
TIME snapshot             — implemented
Sequential BCD conversion — implemented
Ready/valid transmission  — implemented
Timing constraints        — implemented
Quartus synthesis         — passed
Static Timing Analysis    — passed
Automated testbench       — not added yet
```

Текущий архитектурный milestone:

```text
Divider-based TIME formatter
        ↓
Sequential subtract-by-10 TIME formatter
        ↓
resource usage reduced
timing margin increased
```