"""Template for screensavers."""
from sys import exit as sys_exit

from pygame import event
from pygame import init as pygame_init  # pylint: disable=no-name-in-module
from pygame.display import flip, set_mode
from pygame.locals import MOUSEBUTTONDOWN, NOFRAME, QUIT  # pylint: disable=no-name-in-module
from pygame.time import Clock

# Constants
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 1280
BACKGROUND_COLOR = (0, 0, 0)


def main():
    """Main function."""
    pygame_init()
    screen = set_mode((WINDOW_WIDTH, WINDOW_HEIGHT), NOFRAME)
    clock = Clock()
    running = True
    while running:
        for pygame_event in event.get():
            if pygame_event.type in (QUIT, MOUSEBUTTONDOWN):
                running = False
        screen.fill(BACKGROUND_COLOR)
        flip()
        clock.tick(60)
    sys_exit()


if __name__ == "__main__":
    main()
