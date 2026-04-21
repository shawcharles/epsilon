module Epsilon

export epsilon_version

"""
    epsilon_version()

Return the installed Epsilon package version.
"""
epsilon_version() = pkgversion(@__MODULE__)

end
