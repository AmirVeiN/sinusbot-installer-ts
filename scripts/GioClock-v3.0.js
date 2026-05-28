registerPlugin({
    name: 'GioClock-v3.0',
    version: '3.0',
    description: 'Digital Clock with Date, Time.',
    author: 'GioCombo <email@giocombo.com> <giocombo.com>',
    vars: {
        channelIdNormal: {
            title: 'Channel for Normal Time',
            type: 'channel'
        },
        channelId1: {
            title: 'Channel for Special Line #1',
            type: 'channel'
        },
        channelId2: {
            title: 'Channel for Special Line #2',
            type: 'channel'
        },
        channelId3: {
            title: 'Channel for Special Line #3',
            type: 'channel'
        },
        channelId4: {
            title: 'Channel for Special Line #4',
            type: 'channel'
        },
        channelIdDate: {
            title: 'Channel for Date',
            type: 'channel'
        },
        channelIdDev: {
            title: 'Channel for Dev',
            type: 'channel'
        },
        dateformat: {
            title: 'Date format',
            type: 'select',
            options: [
                'DD.MM.YYYY',
                'MM.DD.YYYY',
                'YYYY.MM.DD',
                'YYYY.DD.MM'
            ]
        },
        format: {
            title: 'Time format',
            type: 'select',
            options: [
                '24h',
                '12h'
            ]
        },
        timezone: {
            title: 'Time zone',
            type: 'select',
            options: [
                'UTC-12:00',
                'UTC-11:00',
                'UTC-10:00',
                'UTC-09:30',
                'UTC-09:00',
                'UTC-08:00',
                'UTC-07:00',
                'UTC-06:00',
                'UTC-05:00',
                'UTC-04:30',
                'UTC-04:00',
                'UTC-03:30',
                'UTC-03:00',
                'UTC-02:00',
                'UTC-01:00',
                'UTC±00:00',
                'UTC+01:00',
                'UTC+02:00',
                'UTC+03:00',
                'UTC+03:30',
                'UTC+04:00',
                'UTC+04:30',
                'UTC+05:00',
                'UTC+05:30',
                'UTC+05:45',
                'UTC+06:00',
                'UTC+06:30',
                'UTC+07:00',
                'UTC+08:00',
                'UTC+08:30',
                'UTC+08:45',
                'UTC+09:00',
                'UTC+09:30',
                'UTC+10:00',
                'UTC+10:30',
                'UTC+11:00',
                'UTC+12:00',
                'UTC+12:45',
                'UTC+13:00',
                'UTC+14:00'
            ]
        },
        fontStyle: {
            title: 'Font Style for Special Lines',
            type: 'select',
            options: [
                'Style 1 (Default)',
                'Style 2 (Bold)'
            ]
        },
        dev: {
            title: 'Developed by GioCombo',
            type: 'GioCombo'
        },
    }
}, function (sinusbot, config) {
    var engine = require('engine');
    var backend = require('backend');

    // Zonas horarias
    var tz = [-12, -11, -10, -9.5, -9, -8, -7, -6, -5, -4.5, -4, -3.5, -3, -2, -1, 0, 1, 2, 3, 3.5, 4, 4.5, 5, 5.5, 5.75, 6, 6.5, 7, 8, 8.5, 8.75, 9, 9.5, 10, 10.5, 11, 12, 12.75, 13, 14];

    var fontStyles = [
        // Style 1 (Default)
        [
            ['█▀▀▀█─', '─▄█─', '▄▀▀▀▄─', '▄▀▀▀▄─', '───▄█──', '█▀▀▀▀─', '█▀▀▀█─', '█▀▀▀█─', '▄▀▀▀▄─', '█▀▀▀█─', '────'],
            ['█───█─', '▀─█─', '───▄▀─', '──▄▄█─', '─▄▀─█──', '█▄▄▄──', '█─────', '────█─', '▀▄▄▄▀─', '█▄▄▄█─', '─▀──'],
            ['█───█─', '──█─', '─▄▀───', '────█─', '█▄▄▄█▄─', '────█─', '█▀▀▀█─', '────█─', '█───█─', '────█─', '────'],
            ['█▄▄▄█─', '──█─', '█▄▄▄▄─', '▀▄▄▄▀─', '────█──', '▀▄▄▄▀─', '█▄▄▄█─', '────█─', '▀▄▄▄▀─', '█▄▄▄█─', '─▀──']
        ],
        // Style 2 (Bold)
        [
            ['█▀▀▀█─', '─█─', '▀▀▀▀█─', '▀▀▀▀█─', '█───█─', '█▀▀▀▀─', '█▀▀▀▀─', '▀▀▀▀█─', '█▀▀▀█─', '█▀▀▀█─', '────'],
            ['█───█─', '─█─', '▄▄▄▄█─', '─▄▄▄█─', '█▄▄▄█─', '█▄▄▄▄─', '█▄▄▄▄─', '────█─', '█▄▄▄█─', '█▄▄▄█─', '─▀──'],
            ['█───█─', '─█─', '█─────', '────█─', '────█─', '────█─', '█───█─', '────█─', '█───█─', '────█─', '─▄──'],
            ['▀▀▀▀▀─', '─▀─', '▀▀▀▀▀─', '▀▀▀▀▀─', '────▀─', '▀▀▀▀▀─', '▀▀▀▀▀─', '────▀─', '▀▀▀▀▀─', '▀▀▀▀▀─', '────']
        ]
    ];

    function formatDate(date) {
        var day = date.getDate();
        var month = date.getMonth() + 1;
        var year = date.getFullYear();

        if (day < 10) day = '0' + day;
        if (month < 10) month = '0' + month;

        switch (config.dateformat) {
            case 0: // DD.MM.YYYY
                return day + '.' + month + '.' + year;
            case 1: // MM.DD.YYYY
                return month + '.' + day + '.' + year;
            case 2: // YYYY.MM.DD
                return year + '.' + month + '.' + day;
            case 3: // YYYY.DD.MM
                return year + '.' + day + '.' + month;
            default:
                return day + '.' + month + '.' + year; // Por defecto: DD.MM.YYYY
        }
    }

    var devNames = ["Developed by GioCombo", "Pagina Web: GioCombo.com", "Discord: @GioCombo", "Twitter: @GioCombo_"];
    var devIndex = 0;

    function updateClock() {
        var nonutc = new Date();
        var utc = nonutc.getTime() + (nonutc.getTimezoneOffset() * 60000);
        var time = new Date(utc + (3600000 * tz[config.timezone]));
        var hours = time.getHours();
        var minutes = time.getMinutes();
        var ampm = '';

        if (config.format == 1) {
            ampm = hours >= 12 ? 'PM' : 'AM';
            hours = hours % 12 || 12;
        }

        minutes = minutes < 10 ? '0' + minutes : minutes;

        var timeStringNormal = '[cspacer]' + hours + ':' + minutes;
        if (config.format == 1) {
            timeStringNormal += ' ' + ampm;
        }

        var font = fontStyles[config.fontStyle];
        var lines = ['', '', '', ''];
        for (var i = 0; i < 4; i++) {
            lines[i] = '[cspacer]';
            if (hours >= 10) {
                lines[i] += font[i][Math.floor(hours / 10)];
            } else {
                lines[i] += font[i][0];
            }
            lines[i] += font[i][hours % 10];
            lines[i] += font[i][10]; // :
            lines[i] += font[i][Math.floor(minutes / 10)];
            lines[i] += font[i][minutes % 10];
        }

        var dateString = formatDate(time);

        var devName = devNames[devIndex];

        // Actualizar solo los canales que existen
        if (config.channelIdNormal) {
            var channelNormal = backend.getChannelByID(config.channelIdNormal);
            if (channelNormal) {
                channelNormal.update({ name: timeStringNormal });
            }
        }

        if (config.channelId1) {
            var channel1 = backend.getChannelByID(config.channelId1);
            if (channel1) {
                channel1.update({ name: lines[0] });
            }
        }

        if (config.channelId2) {
            var channel2 = backend.getChannelByID(config.channelId2);
            if (channel2) {
                channel2.update({ name: lines[1] });
            }
        }

        if (config.channelId3) {
            var channel3 = backend.getChannelByID(config.channelId3);
            if (channel3) {
                channel3.update({ name: lines[2] });
            }
        }

        if (config.channelId4) {
            var channel4 = backend.getChannelByID(config.channelId4);
            if (channel4) {
                channel4.update({ name: lines[3] });
            }
        }

        if (config.channelIdDate) {
            var channelDate = backend.getChannelByID(config.channelIdDate);
            if (channelDate) {
                channelDate.update({ name: '[cspacer]' + dateString });
            }
        }

        if (config.channelIdDev) {
            var channelDev = backend.getChannelByID(config.channelIdDev);
            if (channelDev) {
                channelDev.update({ name: '[cspacer]' + devName });
            }
        }
    }

    function toggleDev() {
        devIndex = (devIndex + 1) % devNames.length;
        setTimeout(toggleDev, 25000);
    }

    // Actualizar el reloj cada 1 segundo
    setInterval(updateClock, 1000);

    // Alternar el nombre del Dev
    setTimeout(toggleDev, 25000);

    // Actualizar el reloj inmediatamente al cargar el script
    updateClock();

    engine.log("GioClock-v3.0 ha sido inicializado...");
});
