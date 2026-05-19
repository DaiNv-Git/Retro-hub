import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# We need to find `class DetailScreen extends StatefulWidget {` and everything until the end of the file or next main class.
# In this file, there are no other classes after _DetailScreenState. Wait, there are! Let's check what's after _DetailScreenState.
