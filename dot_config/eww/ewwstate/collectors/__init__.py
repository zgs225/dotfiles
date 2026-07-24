"""Collector package.

Every ``*.py`` module here is auto-imported by the daemon at startup; each
registers its collectors via the ``@collector`` decorator. Add a new collector
by dropping a file in this directory — no other wiring required.
"""
