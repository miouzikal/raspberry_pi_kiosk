"""Wolfram Elementary Cellular Automaton Simulator."""
from argparse import ArgumentParser
from random import choice, randint
from sys import exit as sys_exit
from typing import List

from numpy import array, binary_repr, concatenate, dot, int64, stack, zeros
from numpy.typing import NDArray
from pygame import Surface, draw, event
from pygame import init as pygame_init  # pylint: disable=no-name-in-module
from pygame.display import flip, set_mode
from pygame.locals import MOUSEBUTTONDOWN, NOFRAME, QUIT  # pylint: disable=no-name-in-module
from pygame.time import Clock

WINDOW_WIDTH = 800
WINDOW_HEIGHT = 1280
BACKGROUND_COLOR = (0, 0, 0)
CELL_COLOR = (255, 255, 255)
State = NDArray[int64]
Rule = NDArray[int64]


def get_rule(rule_number: int) -> Rule:
    """Return the rule set for the given Wolfram rule number."""
    return array([int(digit) for digit in binary_repr(rule_number, width=8)])


def step(state: State, rule: Rule) -> State:
    """Compute the next state of the automaton with edge wrapping."""
    wrapped_state = concatenate(([state[-1]], state, [state[0]]))
    neighborhood = stack([wrapped_state[:-2], wrapped_state[1:-1], wrapped_state[2:]], axis=1)
    index: State = 7 - dot(neighborhood, [4, 2, 1])
    return rule[index]


def render(screen: Surface, states: List[State], cell_size: int):
    """Render the states on the screen."""
    for row, state in enumerate(states):
        for col, cell in enumerate(state):
            if cell:
                x = col * cell_size
                y = row * cell_size
                draw.rect(screen, CELL_COLOR, (x, y, cell_size, cell_size))


def initialize_state(width: int, cell_size: int, random_init: bool) -> State:
    """Initialize the state of the automaton."""
    state = zeros(width // cell_size, dtype=int)
    if random_init:
        state = array([choice([0, 1]) for _ in range(len(state))])
    else:
        state[len(state) // 2] = 1
    return state


def main(rule_number: int, fps: int, random_init: bool, cell_size: int):
    """Main function."""
    pygame_init()
    screen = set_mode((WINDOW_WIDTH, WINDOW_HEIGHT), NOFRAME)
    clock = Clock()
    state = initialize_state(WINDOW_WIDTH, cell_size, random_init)
    rule = get_rule(rule_number)
    states = [state]
    running = True
    while running:
        for pygame_event in event.get():
            if pygame_event.type in (QUIT, MOUSEBUTTONDOWN):
                running = False
        screen.fill(BACKGROUND_COLOR)
        state = step(state, rule)
        states.append(state)
        if len(states) * cell_size > WINDOW_HEIGHT:
            states.pop(0)
        render(screen, states, cell_size)
        flip()
        clock.tick(fps)
    sys_exit()


if __name__ == "__main__":
    parser = ArgumentParser(description="Wolfram Cellular Automaton Simulator")
    parser.add_argument("--cell-size", type=int, default=5, help="Size of each cell")
    parser.add_argument("--rule-number", type=int, default=randint(1, 256), help="Rule number")
    parser.add_argument("--fps", type=int, default=60, help="Frames per second")
    parser.add_argument("--random-init", action="store_true", help="Use a random initial state")
    args = parser.parse_args()
    main(args.rule_number, args.fps, args.random_init, args.cell_size)
