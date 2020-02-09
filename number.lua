-- Number helpers
function round(number, steps) -- Rounds a number
    steps = steps or 1
    return math.floor(number * steps + 0.5) / steps
end
