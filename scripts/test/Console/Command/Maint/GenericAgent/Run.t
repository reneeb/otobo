# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2020 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

use strict;
use warnings;
use utf8;

# Set up the test driver $Self when we are running as a standalone script.
use Kernel::System::UnitTest::RegisterDriver;
use Kernel::System::UnitTest::MockTime qw(:all);

use vars (qw($Self));

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase  => 1,
        UseTmpArticleDir => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# get ticket object
my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

# cleanup
my @TicketIDs = $TicketObject->TicketSearch(
    Title  => 'UnitTestSafeToDelete',
    UserID => 1,

);

for my $TicketID (@TicketIDs) {
    my $Success = $TicketObject->TicketDelete(
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->True(
        $Success,
        "Initial Cleanup TicketDelete() - for TicketID $TicketID with true",
    );
}

# setup the environment
my %TicketConfig = (
    Title        => 'UnitTestSafeToDelete',
    Queue        => 'Raw',
    Lock         => 'unlock',
    PriorityID   => 3,
    State        => 'new',
    CustomerID   => '123465',
    CustomerUser => 'customer@example.com',
    OwnerID      => 1,
    UserID       => 1,
);

# freeze time
FixedTimeSet();

my $TicketID1 = $TicketObject->TicketCreate(%TicketConfig);
$Self->IsNot(
    $TicketID1,
    undef,
    "Setup TicketCreate() - TicketID should not be undef"
);

# make sure the next ticket is created 1 minute after
$Helper->FixedTimeAddSeconds(60);

my $TicketID2 = $TicketObject->TicketCreate(%TicketConfig);
$Self->IsNot(
    $TicketID2,
    undef,
    "Setup TicketCreate() - TicketID should not be undef"
);

my $ConfigurationModule = 'scripts::test::sample::GenericAgent::TestConfigurationModule';

my @Tests = (
    {
        Name     => 'Missing configuration module',
        Params   => [],
        ExitCode => 1,
    },
    {
        Name     => 'not existing configuration module',
        Params   => [ '--configuration-module', 'scripts::test::sample::GenericAgent::Test', ],
        ExitCode => 1,
    },
    {
        Name            => 'custom configuration module',
        Params          => [ '--configuration-module', $ConfigurationModule, ],
        ExitCode        => 0,
        AffectedTickets => {
            $TicketID1 => 1,
            $TicketID2 => 1,
        },
    },
    {
        Name            => 'custom configuration module limit',
        Params          => [ '--configuration-module', $ConfigurationModule, '--ticket-limit', '1' ],
        ExitCode        => 0,
        AffectedTickets => {
            $TicketID2 => 1,
        },
    },
    {
        Name      => 'custom configuration module locked',
        Params    => [ '--configuration-module', $ConfigurationModule, ],
        ExitCode  => 1,
        CreatePID => 1,
    },
    {
        Name            => 'custom configuration module force',
        Params          => [ '--configuration-module', $ConfigurationModule, '--force-pid' ],
        ExitCode        => 1,
        ExitCode        => 0,
        AffectedTickets => {
            $TicketID1 => 1,
            $TicketID2 => 1,
        },
    },
);

# get command object
my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::GenericAgent::Run');

TESTCASE:
for my $Test (@Tests) {

    if ( $Test->{CreatePID} ) {
        my $Name = substr 'GenericAgentFile-' . $ConfigurationModule, 0, 200;
        $Kernel::OM->Get('Kernel::System::PID')->PIDCreate(
            Name  => $Name,
            Force => 1,
        );
    }

    my $ExitCode = $CommandObject->Execute( @{ $Test->{Params} } );

    $Self->Is(
        $ExitCode,
        $Test->{ExitCode},
        "$Test->{Name} Maint::GenericAgent::Run - exit code",
    );

    next TESTCASE if $Test->{ExitCode};

    for my $TicketID ( $TicketID1, $TicketID2 ) {

        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
        );

        if ( $Test->{AffectedTickets}->{$TicketID} ) {
            $Self->Is(
                $Ticket{PriorityID},
                5,
                "$Test->{Name} affected ticket check ($TicketID) - PriorityID should be 5",
            );
            $Self->Is(
                $Ticket{State},
                'open',
                "$Test->{Name} affected ticket check ($TicketID) - State should be open",
            );
            my $Success = $TicketObject->TicketPrioritySet(
                TicketID   => $TicketID,
                PriorityID => $TicketConfig{PriorityID},
                UserID     => 1,
            );
            $Self->True(
                $Success,
                "$Test->{Name} TicketUpdate() - restore priority for TicketID $TicketID with true",
            );
            $Success = $TicketObject->TicketStateSet(
                TicketID => $TicketID,
                State    => $TicketConfig{State},
                UserID   => 1,
            );
            $Self->True(
                $Success,
                "$Test->{Name} TicketUpdate() - restore state for TicketID $TicketID with true",
            );
        }
        else {
            $Self->Is(
                $Ticket{PriorityID},
                $TicketConfig{PriorityID},
                "$Test->{Name} not affected ticket check ($TicketID) - PriorityID should be $TicketConfig{PriorityID}",
            );
            $Self->Is(
                $Ticket{State},
                $TicketConfig{State},
                "$Test->{Name} not affected ticket check ($TicketID) - State should be $TicketConfig{State}",
            );
        }
    }
}

# cleanup is done by RestoreDatabase


$Self->DoneTesting();


