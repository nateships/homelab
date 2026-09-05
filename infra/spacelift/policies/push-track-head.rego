package spacelift

# Advance every stack's tracked head on each push to its branch, and
# start a run only when the push touches the stack's own files - the
# same affected-files rule Spacelift applies without a policy. Without
# the unconditional head advance, a dependency-triggered run executes
# the stack's last *matching* commit, which can be weeks old; the
# runner image is baked from latest main, so a stale checkout asks
# mise for tool versions the image no longer carries and dies at
# install time.

track if {
	input.push.branch == input.stack.branch
	input.push.tag == ""
}

propose if not is_null(input.pull_request)

# Consulted only when track is true: the head still advances.
notrigger if not affected

affected if {
	some f in input.push.affected_files
	startswith(f, sprintf("%s/", [input.stack.project_root]))
}

affected if {
	some f in input.push.affected_files
	some g in input.stack.additional_project_globs
	glob.match(g, ["/"], f)
}
