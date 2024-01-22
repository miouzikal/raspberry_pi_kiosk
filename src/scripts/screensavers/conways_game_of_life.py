"""Conway's Game of Life Simulator."""
from argparse import ArgumentParser
from sys import exit as sys_exit

from numpy import array, bool_, roll
from numpy import sum as np_sum
from numpy import where
from numpy.random import randint  # pyright: ignore[reportUnknownVariableType]
from numpy.typing import NDArray
from pygame import Surface, draw, event
from pygame import init as pygame_init  # pylint: disable=no-name-in-module
from pygame.display import flip, set_mode
from pygame.locals import MOUSEBUTTONDOWN, NOFRAME, QUIT  # pylint: disable=no-name-in-module
from pygame.time import Clock

# Constants
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 1280
BACKGROUND_COLOR = (0, 0, 0)
CELL_COLOR = (255, 255, 255)
State = NDArray[bool_]


def get_neighbors(state: State) -> State:
    """Return the count of neighbors for each cell."""
    rolled_states = (roll(roll(state, i, 0), j, 1) for i in (-1, 0, 1) for j in (-1, 0, 1) if (i != 0 or j != 0))
    neighbors = np_sum(array(list(rolled_states)), axis=0)
    return neighbors


def step(state: State) -> State:
    """Compute the next state of the Game of Life using vectorized operations."""
    neighbors = get_neighbors(state)
    new_state = where((state == 1) & ((neighbors == 2) | (neighbors == 3)), 1, 0)
    new_state += where((state == 0) & (neighbors == 3), 1, 0)
    return new_state


def render(screen: Surface, state: State, cell_size: int):
    """Render the state on the screen."""
    rows, cols = state.shape
    for x in range(rows):
        for y in range(cols):
            if state[x, y]:
                rect_x, rect_y = x * cell_size, y * cell_size
                draw.rect(screen, CELL_COLOR, (rect_x, rect_y, cell_size, cell_size))


def initialize_state(width: int, height: int, cell_size: int) -> State:
    """Initialize the state of the Game of Life."""
    rows, cols = width // cell_size, height // cell_size
    return randint(2, size=(rows, cols), dtype=bool)


def main(fps: int, cell_size: int):
    """Main function."""
    pygame_init()
    screen = set_mode((WINDOW_WIDTH, WINDOW_HEIGHT), NOFRAME)
    clock = Clock()
    state = initialize_state(WINDOW_WIDTH, WINDOW_HEIGHT, cell_size)
    running = True
    while running:
        for pygame_event in event.get():
            if pygame_event.type in (QUIT, MOUSEBUTTONDOWN):
                running = False
        screen.fill(BACKGROUND_COLOR)
        state = step(state)
        render(screen, state, cell_size)
        flip()
        clock.tick(fps)
    sys_exit()


if __name__ == "__main__":
    parser = ArgumentParser(description="Conway's Game of Life Simulator")
    parser.add_argument("--cell-size", type=int, default=10, help="Size of each cell")
    parser.add_argument("--fps", type=int, default=10, help="Frames per second")
    args = parser.parse_args()
    main(args.fps, args.cell_size)
