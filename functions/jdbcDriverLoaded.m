function loaded = jdbcDriverLoaded(driverPath)
    loaded = false;
    driverPath = char(driverPath);
    if ~isfile(driverPath)
        warning('JDBC driver not found: %s', driverPath);
        return
    end
    loaded = true;
end

