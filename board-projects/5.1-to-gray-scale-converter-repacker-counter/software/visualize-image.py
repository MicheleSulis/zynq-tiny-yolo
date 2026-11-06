import serial
import numpy as np
import matplotlib.pyplot as plt

PORT = "/dev/tty.usbserial-130"
BAUD = 115200 * 4

WIDTH = 683
HEIGHT = 1024

START_MARKER = b"STARTIMG\r\n"
END_MARKER = b"ENDIMG\r\n"

ser = serial.Serial(PORT, BAUD, timeout=600)

print("Waiting for image...")

while True:
    line = ser.readline()
    if line == START_MARKER:
        break

    if line:
        print(line.decode(errors="replace").rstrip())


print("Receiving image...")

img = np.zeros((HEIGHT, WIDTH), dtype=np.uint8)

plt.ion()
fig, ax = plt.subplots()
display = ax.imshow(img, cmap="gray", vmin=0, vmax=255)
ax.set_title("Received image")
plt.show()

ROWS_PER_UPDATE = 1024

for row in range(0, HEIGHT, ROWS_PER_UPDATE):
    rows = min(ROWS_PER_UPDATE, HEIGHT - row)
    size = rows * WIDTH

    data = bytearray()

    while len(data) < size:
        chunk = ser.read(size - len(data))

        if not chunk:
            raise RuntimeError("UART timeout while receiving image")

        data.extend(chunk)

    img[row:row + rows, :] = np.frombuffer(
        data, dtype=np.uint8
    ).reshape(rows, WIDTH)

    display.set_data(img)
    fig.canvas.draw_idle()
    plt.pause(0.001)


marker = ser.readline()

if marker != END_MARKER:
    print("Warning: end marker not received correctly")
else:
    print("Image received:")

ser.close()

plt.ioff()
plt.show()
