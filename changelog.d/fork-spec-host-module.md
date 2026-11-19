### Fixed

- A fork whose name matches one of `spec/bin/fork_spec.rb`'s sample names, `my_app` or `acmegarden`, can push again: the spec no longer counts the fork's own module as a taken name, so `bin/fork` stops aborting the suite mid-run.
