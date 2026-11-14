TaskListUtils = {}
local g_currentModName = g_currentModName

function TaskListUtils.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[TaskListUtils.deepcopy(orig_key)] = TaskListUtils.deepcopy(orig_value)
        end
        setmetatable(copy, TaskListUtils.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--- Period->month offset matches g_i18n:formatPeriod: +2 northern maps, +8 southern (latitude < 0).
function TaskListUtils.getPeriodMonthOffset()
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    local daylight = env ~= nil and env.daylight or nil
    if daylight ~= nil and daylight.latitude ~= nil and daylight.latitude < 0 then
        return 8
    end
    return 2
end

function TaskListUtils.convertMonthNumberToPeriod(month)
    month = month - TaskListUtils.getPeriodMonthOffset()
    if month <= 0 then
        month = month + 12
    end
    return month
end

function TaskListUtils.convertPeriodToMonthNumber(period)
    period = period + TaskListUtils.getPeriodMonthOffset()
    if period > 12 then
        period = period - 12
    end
    return period
end

--- Folds a game period or month slot into 1..12 (e.g. after adding N-month intervals, including N > 12).
function TaskListUtils.normalizePeriod(period)
    if period == nil then
        return 1
    end
    local p = math.floor(tonumber(period) or 1)
    while p > 12 do
        p = p - 12
    end
    while p < 1 do
        p = p + 12
    end
    return p
end

function TaskListUtils.formatPeriodFullMonthName(period, useShort)
    return g_i18n:formatPeriod(period, useShort)
end

-- Courtesy of PowerTools
function TaskListUtils.showOptionDialog(parameters)
    OptionDialog.createFromExistingGui({
        options = parameters.options,
        optionText = parameters.text,
        optionTitle = parameters.title,
        callbackFunc = parameters.callback,
    }, parameters.name or g_currentModName .. "OptionDialog")

    local optionDialog = OptionDialog.INSTANCE

    if parameters.okButtonText ~= nil or parameters.cancelButtonText ~= nil then
        optionDialog:setButtonTexts(parameters.okButtonText, parameters.cancelButtonText)
    end

    local defaultOption = parameters.defaultOption or 1

    optionDialog.optionElement:setState(defaultOption)

    if parameters.callback and (type(parameters.callback)) == "function" then
        optionDialog:setCallback(parameters.callback, parameters.target, parameters.args)
    end
end

TaskListUtils.taskSortingFunction = function(t1, t2)
    if t1.period == nil or t2.period == nil then
        return false
    end

    if t1.period == t2.period then
        return t1.priority < t2.priority
    end
    return t1.period < t2.period
end
