CREATE TABLE IF NOT EXISTS `vuilnisman_levels` (
    `identifier` VARCHAR(60) NOT NULL,
    `level` INT NOT NULL DEFAULT 1,
    `xp` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`identifier`)
);
