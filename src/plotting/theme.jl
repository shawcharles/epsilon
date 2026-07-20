using CairoMakie

const _EPSILON_CATEGORICAL_PALETTE = [
    colorant"#0B6E4F",
    colorant"#F26419",
    colorant"#33658A",
    colorant"#A23B72",
    colorant"#F6AE2D",
    colorant"#86BBD8",
    colorant"#758E4F",
    colorant"#C3423F",
]
const _EPSILON_POSITIVE_COLOR = colorant"#0B6E4F"
const _EPSILON_NEGATIVE_COLOR = colorant"#C3423F"
const _EPSILON_NEUTRAL_COLOR = colorant"#33658A"
const _EPSILON_GRID_COLOR = RGBAf(0.0, 0.0, 0.0, 0.08)

"""
    _epsilon_theme_impl() -> Theme

Return the bounded Makie theme for Epsilon plots.

`_epsilon_theme_impl()` is a pure helper: it returns a `Makie.Theme` and does not
mutate Makie's global active theme.
"""
function _epsilon_theme_impl()
    return Theme(
        palette = (
            color = _EPSILON_CATEGORICAL_PALETTE,
            patchcolor = _EPSILON_CATEGORICAL_PALETTE,
        ),
        Figure = (
            backgroundcolor = :white,
            size = (960, 620),
        ),
        Axis = (
            backgroundcolor = :white,
            xgridvisible = false,
            ygridvisible = true,
            ygridcolor = _EPSILON_GRID_COLOR,
            leftspinevisible = true,
            rightspinevisible = false,
            topspinevisible = false,
            bottomspinevisible = true,
            xlabelsize = 13,
            ylabelsize = 13,
            xticklabelsize = 11,
            yticklabelsize = 11,
            titlesize = 17,
            titlealign = :left,
        ),
        Legend = (
            framevisible = false,
            labelsize = 11,
        ),
        Lines = (
            linewidth = 2.4,
        ),
        Scatter = (
            markersize = 9,
        ),
        Band = (
            alpha = 0.18,
        ),
        Hist = (
            color = _EPSILON_NEUTRAL_COLOR,
            strokewidth = 0.0,
        ),
    )
end
