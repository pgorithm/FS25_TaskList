TaskListUtils = {}
local g_currentModName = g_currentModName
local PERIOD_MONTH_KEYS = {
    "ui_month3",
    "ui_month4",
    "ui_month5",
    "ui_month6",
    "ui_month7",
    "ui_month8",
    "ui_month9",
    "ui_month10",
    "ui_month11",
    "ui_month12",
    "ui_month1",
    "ui_month2",
}

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

function TaskListUtils.convertMonthNumberToPeriod(month)
    month = month - 2
    if month <= 0 then
        month = month + 12
    end
    return month
end

function TaskListUtils.convertPeriodToMonthNumber(period)
    period = period + 2
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

function TaskListUtils.formatPeriodFullMonthName(period)
    local monthKey = PERIOD_MONTH_KEYS[period]

    if monthKey ~= nil then
        return g_i18n:getText(monthKey)
    end
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
