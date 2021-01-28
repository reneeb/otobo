# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2021 Rother OSS GmbH, https://otobo.de/
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

use vars (qw($Self));

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $Helper       = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # Do not check RichText.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Frontend::RichText',
            Value => 0,
        );

        # Enable SMIME due to 'Enable email security' checkbox must be enabled.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'SMIME',
            Value => 1,
        );

        # Create string which length is over 4000 characters.
        my $TooLongString = 'A' x 4001;

        # Create test user and login.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => ['admin'],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ScriptAlias = $ConfigObject->Get('ScriptAlias');

        # Navigate to AdminNotificationEvent screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminNotificationEvent");

        # Check overview screen.
        $Selenium->find_element( "table",             'css' );
        $Selenium->find_element( "table thead tr th", 'css' );
        $Selenium->find_element( "table tbody tr td", 'css' );

        # Check breadcrumb on Overview screen.
        $Self->True(
            $Selenium->find_element( '.BreadCrumb', 'css' ),
            "Breadcrumb is found on Overview screen.",
        );

        # Click "Add notification".
        $Selenium->find_element("//a[contains(\@href, \'Action=AdminNotificationEvent;Subaction=Add' )]")
            ->VerifiedClick();

        $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && \$('#Name').length;" );

        # Check add NotificationEvent screen.
        for my $ID (
            qw(Name Comment ValidID Events en_Subject en_Body)
            )
        {
            my $Element = $Selenium->find_element( "#$ID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # Check breadcrumb on Add screen.
        my $Count = 1;
        for my $BreadcrumbText ( 'Ticket Notification Management', 'Add Notification' ) {
            $Self->Is(
                $Selenium->execute_script("return \$('.BreadCrumb li:eq($Count)').text().trim();"),
                $BreadcrumbText,
                "Breadcrumb text '$BreadcrumbText' is found on screen"
            );

            $Count++;
        }

        # Toggle Ticket filter widget.
        $Selenium->find_element("//a[contains(\@aria-controls, \'Core_UI_AutogeneratedID_1')]")->click();

        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('a[aria-controls=\"Core_UI_AutogeneratedID_1\"]').attr('aria-expanded') === 'true';"
        );

        # Toggle Article filter (Only for ArticleCreate and ArticleSend event) widget.
        $Selenium->find_element("//a[contains(\@aria-controls, \'Core_UI_AutogeneratedID_2')]")->click();

        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('a[aria-controls=\"Core_UI_AutogeneratedID_2\"]').attr('aria-expanded') === 'true';"
        );

        # Create test NotificationEvent.
        my $NotifEventRandomID = 'NotificationEvent' . $Helper->GetRandomID();
        my $NotifEventText     = 'Selenium NotificationEvent test';
        $Selenium->find_element( '#Name',    'css' )->send_keys($NotifEventRandomID);
        $Selenium->find_element( '#Comment', 'css' )->send_keys($NotifEventText);
        $Selenium->InputFieldValueSet(
            Element => '#Events',
            Value   => 'ArticleCreate',
        );
        $Selenium->InputFieldValueSet(
            Element => '#ArticleIsVisibleForCustomer',
            Value   => 1,
        );
        $Selenium->find_element( '#MIMEBase_Subject', 'css' )->send_keys($NotifEventText);
        $Selenium->find_element( '#en_Subject',       'css' )->send_keys($NotifEventText);

        # Check 'Additional recipient' length validation from Additional recipient email addresses (see bug#13936).
        my $FieldValue = "a" x 201;

        # Check TransportEmail checkbox if it is not checked.
        my $TransportEmailCheck = $Selenium->execute_script("return \$('#TransportEmail').prop('checked');");
        if ( !$TransportEmailCheck ) {
            $Selenium->execute_script("\$('#TransportEmail').prop('checked', true);");
            $Selenium->WaitFor( JavaScript => "return \$('#TransportEmail').prop('checked') === true;" );
        }
        $Selenium->find_element( "#RecipientEmail", 'css' )->send_keys($FieldValue);
        $Selenium->find_element( "#Submit",         'css' )->click();
        $Selenium->WaitFor( JavaScript => "return \$('#RecipientEmail.Error').length;" );

        $Self->True(
            $Selenium->execute_script("return \$('#RecipientEmail.Error').length;"),
            "Validation for 'Additional recipient' field is correct",
        );
        $Selenium->find_element( "#RecipientEmail", 'css' )->clear();

        # Input data for bug#14597.
        my $RecipientValue = 'test1@test.com; test2@test.com; test3@test.com';
        $Selenium->find_element( "#RecipientEmail", 'css' )->send_keys($RecipientValue);

        $Self->Is(
            $Selenium->execute_script(
                "return \$('#RecipientEmail').siblings('.FieldExplanation:eq(0)').text().trim();"
            ),
            'Use comma or semicolon to separate email addresses.',
            'Fill explanation for #RecipientEmail format.'
        );

        # Set back TransportEmail checkbox if it was not checked.
        if ( !$TransportEmailCheck ) {
            $Selenium->execute_script("\$('#TransportEmail').prop('checked', false);");
            $Selenium->WaitFor( JavaScript => "return \$('#TransportEmail').prop('checked') === false;" );
        }

        # Insert long string into text area using jQuery, since send_keys() takes too long.
        $Selenium->execute_script(
            "\$('#en_Body').val('$TooLongString').trigger('change');"
        );

        $Selenium->find_element( "#Submit", 'css' )->click();

        # If database backend is PostgreSQL or Oracle, first test body length validation.
        my $DBType = $Kernel::OM->Get('Kernel::System::DB')->{'DB::Type'};
        if (
            $DBType eq 'postgresql'
            || $DBType eq 'oracle'
            )
        {
            $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && \$('.Dialog.Modal').length;" );

            $Self->True(
                $Selenium->execute_script("return \$('#en_Body.ServerError').length;"),
                'Text field has an error'
            );
            $Self->Is(
                $Selenium->execute_script("return \$('.Dialog.Modal .InnerContent p').text().trim();"),
                'One or more errors occurred!',
                "Server error dialog - found"
            );

            $Selenium->find_element( "#DialogButton1", 'css' )->click();
            $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && !\$('.Dialog.Modal').length;" );

            $Selenium->find_element( '#en_Body', 'css' )->clear();
            $Selenium->find_element( '#en_Body', 'css' )->send_keys($NotifEventText);
            $Selenium->find_element( "#Submit",  'css' )->VerifiedClick();

            $TooLongString = $NotifEventText;
        }

        $Selenium->WaitFor(
            JavaScript => "return typeof(\$) === 'function' && \$('table td a:contains($NotifEventRandomID)').length;"
        );

        # Check if test NotificationEvent show on AdminNotificationEvent screen.
        $Self->True(
            $Selenium->execute_script("return \$('table td a:contains($NotifEventRandomID)').length;"),
            "$NotifEventRandomID NotificationEvent found on page",
        );

        # Check is there notification 'Notification added!' after notification is added.
        my $Notification = 'Notification added!';
        $Self->True(
            $Selenium->execute_script("return \$('.MessageBox.Notice p:contains($Notification)').length;"),
            "$Notification - notification is found."
        );

        # Check test NotificationEvent values.
        $Selenium->find_element( $NotifEventRandomID, 'link_text' )->VerifiedClick();

        $Self->Is(
            $Selenium->find_element( '#Name', 'css' )->get_value(),
            $NotifEventRandomID,
            "#Name stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#Comment', 'css' )->get_value(),
            $NotifEventText,
            "#Comment stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#en_Subject', 'css' )->get_value(),
            $NotifEventText,
            "#en_Subject stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#en_Body', 'css' )->get_value(),
            $TooLongString,
            "#en_Body stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#ArticleIsVisibleForCustomer', 'css' )->get_value(),
            '1',
            '#ArticleIsVisibleForCustomer stored value'
        );
        $Self->Is(
            $Selenium->find_element( '#MIMEBase_Subject', 'css' )->get_value(),
            $NotifEventText,
            "#MIMEBase_Subject stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#ValidID', 'css' )->get_value(),
            1,
            "#ValidID stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#RecipientEmail', 'css' )->get_value(),
            $RecipientValue,
            "#RecipientEmail stored value",
        );

        # Check breadcrumb on Edit screen.
        $Count = 1;
        for my $BreadcrumbText (
            'Ticket Notification Management',
            'Edit Notification: ' . $NotifEventRandomID
            )
        {
            $Self->Is(
                $Selenium->execute_script("return \$('.BreadCrumb li:eq($Count)').text().trim();"),
                $BreadcrumbText,
                "Breadcrumb text '$BreadcrumbText' is found on screen"
            );

            $Count++;
        }

        # Edit test NotificationEvent and set it to invalid.
        my $EditNotifEventText = "Selenium edited NotificationEvent test";

        # Toggle Article filter (Only for ArticleCreate and ArticleSend event) widget.
        $Selenium->find_element("//a[contains(\@aria-controls, \'Core_UI_AutogeneratedID_2')]")->click();

        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('a[aria-controls=\"Core_UI_AutogeneratedID_2\"]').attr('aria-expanded') === 'true';"
        );

        $Selenium->find_element( "#Comment",    'css' )->clear();
        $Selenium->find_element( "#en_Body",    'css' )->clear();
        $Selenium->find_element( "#en_Body",    'css' )->send_keys($EditNotifEventText);
        $Selenium->find_element( "#en_Subject", 'css' )->clear();
        $Selenium->find_element( "#en_Subject", 'css' )->send_keys($EditNotifEventText);
        $Selenium->InputFieldValueSet(
            Element => '#ArticleIsVisibleForCustomer',
            Value   => 0,
        );
        $Selenium->find_element( "#MIMEBase_Subject", 'css' )->clear();
        $Selenium->find_element( "#MIMEBase_Body",    'css' )->send_keys($EditNotifEventText);
        $Selenium->InputFieldValueSet(
            Element => '#ValidID',
            Value   => 2,
        );
        $Selenium->find_element( "#Submit", 'css' )->VerifiedClick();

        # Check is there notification 'Notification updated!' after notification is added.
        $Notification = 'Notification updated!';
        $Self->True(
            $Selenium->execute_script("return \$('.MessageBox.Notice p:contains($Notification)').length;"),
            "$Notification - notification is found."
        );

        # Check edited NotifcationEvent values.
        $Selenium->find_element( $NotifEventRandomID, 'link_text' )->VerifiedClick();

        $Self->Is(
            $Selenium->find_element( '#Comment', 'css' )->get_value(),
            "",
            "#Comment updated value",
        );
        $Self->Is(
            $Selenium->find_element( '#en_Body', 'css' )->get_value(),
            $EditNotifEventText,
            "#en_Body updated value",
        );
        $Self->Is(
            $Selenium->find_element( '#ArticleIsVisibleForCustomer', 'css' )->get_value(),
            '0',
            '#ArticleIsVisibleForCustomer updated value'
        );
        $Self->Is(
            $Selenium->find_element( '#MIMEBase_Subject', 'css' )->get_value(),
            "",
            "#MIMEBase_Subject updated value",
        );
        $Self->Is(
            $Selenium->find_element( '#MIMEBase_Body', 'css' )->get_value(),
            $EditNotifEventText,
            "#MIMEBase_Body updated value",
        );
        $Self->Is(
            $Selenium->find_element( '#ValidID', 'css' )->get_value(),
            2,
            "#ValidID updated value",
        );

        # Test javascript enable/disable actions on checkbox checking.
        my @InputFields = (
            "EmailSigningCrypting_Search",
            "EmailMissingSigningKeys_Search",
            "EmailMissingCryptingKeys_Search"
        );

        # Set initial checkbox state.
        $Selenium->execute_script("\$('#EmailSecuritySettings').prop('checked', false);");

        my @Tests = (
            {
                Name     => 'Input fields are enabled',
                HasClass => 0,
            },
            {
                Name     => 'Input fields are disabled',
                HasClass => 1,
            }
        );

        for my $Test (@Tests) {
            $Selenium->find_element( "#EmailSecuritySettings", 'css' )->click();

            for my $InputField (@InputFields) {
                $Selenium->WaitFor(
                    JavaScript => "return \$('.AlreadyDisabled #$InputField').length === $Test->{HasClass};"
                );

                $Self->Is(
                    $Selenium->execute_script(
                        "return \$('#$InputField').parent().hasClass('AlreadyDisabled');"
                    ),
                    $Test->{HasClass},
                    $Test->{Name},
                );
            }
        }

        # Check adding new notification text.
        #   See bug bug#13883 - (https://bugs.otrs.org/show_bug.cgi?id=13883).
        my @Languages = (
            {
                Language => 'Deutsch - German',
                LangCode => 'de',
            },
            {
                Language => 'Español - Spanish',
                LangCode => 'es',
            },
            {
                Language => 'Magyar - Hungarian',
                LangCode => 'hu',
            },
        );

        for my $Lang (@Languages) {

            # Add new notification text.
            $Selenium->InputFieldValueSet(
                Element => '#Language',
                Value   => $Lang->{LangCode},
            );

            $Self->IsNot(
                $Selenium->execute_script(
                    "return \$('#Language_Search').closest('div').find('.Text').text().trim();"
                ),
                $Lang->{Language},
                'Language is not selected in select box'
            );

            # Collaps notification text.
            $Selenium->execute_script(
                "\$('.NotificationLanguage h2:contains($Lang->{Language})').siblings().find('a').first().click();"
            );

            $Self->True(
                $Selenium->execute_script(
                    "return \$('.NotificationLanguage h2:contains($Lang->{Language})').closest('.WidgetSimple').hasClass('Collapsed');"
                ),
                'Language box is colapsed'
            );

        }

        # Delete first added test notificaton text.
        $Selenium->execute_script("\$('#$Languages[0]->{LangCode}_Language_Remove').click();");

        $Selenium->WaitFor( AlertPresent => 1 );

        $Self->Is(
            $Selenium->get_alert_text(),
            'Do you really want to delete this notification language?',
            'Check for open confirm text',
        );

        $Selenium->accept_alert();
        sleep 2;

        eval {
            $Self->Is(
                $Selenium->get_alert_text(),
                '',
                'Check if confirm dialog is closed',
            );
        };

        # Go back to AdminNotificationEvent overview screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminNotificationEvent");

        # Check class of invalid NotificationEvent in the overview table.
        $Self->True(
            $Selenium->execute_script(
                "return \$('tr.Invalid td a:contains($NotifEventRandomID)').length;"
            ),
            "There is a class 'Invalid' for test NotificationEvent",
        );

        # Get NotificationEventID.
        my %NotifEventID = $Kernel::OM->Get('Kernel::System::NotificationEvent')->NotificationGet(
            Name => $NotifEventRandomID
        );

        # Delete test notification with delete button.
        $Selenium->find_element("//a[contains(\@href, \'Subaction=Delete;ID=$NotifEventID{ID}' )]")->click();
        $Selenium->WaitFor( AlertPresent => 1 );
        $Selenium->accept_alert();

        $Selenium->WaitFor(
            JavaScript =>
                'return typeof(Core) == "object" && typeof(Core.App) == "object" && Core.App.PageLoadComplete;'
        );
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && !\$('tr.Invalid td a:contains($NotifEventRandomID)').length;"
        );

        # Check if test NotificationEvent is deleted.
        $Self->False(
            $Selenium->execute_script(
                "return \$('tr.Invalid td a:contains($NotifEventRandomID)').length;"
            ),
            "Test NotificationEvent is deleted - $NotifEventRandomID",
        ) || die;

        my $Location = $ConfigObject->Get('Home')
            . "/scripts/test/sample/NotificationEvent/Export_Notification_Ticket_create_notification.yml";

        # Import existing template without overwrite.
        $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);

        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('#FileUpload').val().indexOf('Export_Notification_Ticket_create_notification.yml') !== -1;"
        );

        $Self->True(
            $Selenium->execute_script(
                "return \$('#FileUpload').val().indexOf('Export_Notification_Ticket_create_notification.yml') !== -1;"
            ),
            "Notification is uploaded",
        );

        $Selenium->find_element("//button[\@value=\'Upload Notification configuration']")->VerifiedClick();

        my $ErrorMessage = 'There where errors adding/updating the following Notifications';
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && !\$('tr.Invalid td a:contains($ErrorMessage)').length;"
        );

        $Selenium->WaitFor( JavaScript => "return \$('p:contains($ErrorMessage)').length;" );

        $Selenium->find_element(
            "//p[contains(text(), \'There where errors adding/updating the following Notifications')]"
        );

        # Import existing template with overwrite.
        $Selenium->find_element( "#FileUpload", 'css' )->send_keys($Location);

        $Selenium->find_element( "#OverwriteExistingNotifications", 'css' )->click();

        $Selenium->find_element("//button[\@value=\'Upload Notification configuration']")->VerifiedClick();

        $Selenium->find_element("//p[contains(text(), \'The following Notifications have been updated successfully')]");

       # For English notification text remove button is added.
       # Notification text it is not shown on add screen if DefaultUsedLanguages has no English included. See bug#14594.
        my $NotificationEventObject = $Kernel::OM->Get('Kernel::System::NotificationEvent');
        my $NotificationID          = $NotificationEventObject->NotificationAdd(
            Name => "Notification$Helper->GetRandomID()",
            Data => {
                Events => ['TicketQueueUpdate'],
            },
            Message => {
                en => {
                    Subject     => 'Hello',
                    Body        => 'Hello World',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject     => 'Hallo',
                    Body        => 'Hallo Welt',
                    ContentType => 'text/plain',
                },
            },
            Comment => 'An optional comment',
            ValidID => 1,
            UserID  => 1,
        );

        # Set only one language as default.
        $Helper->ConfigSettingChange(
            Key   => 'DefaultUsedLanguages',
            Valid => 1,
            Value => {
                de => 'German'
            },
        );

        # Navigate to AdminNotificationEvent add screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminNotificationEvent;Subaction=Add");

        # Check if only Germen notification is shown.
        $Self->Is(
            $Selenium->execute_script(
                "return \$('.NotificationLanguage h2:contains(\"Deutsch - German\")').text().trim();"
            ),
            'Deutsch - German',
            "Language box is Deutsch - German"
        );

        # Go to notification witch is created with English notification text.
        $Selenium->VerifiedGet(
            "${ScriptAlias}index.pl?Action=AdminNotificationEvent;Subaction=Change;ID=$NotificationID"
        );

        $Self->Is(
            $Selenium->execute_script(
                "return \$('.AdditionalInformation #en_Language_Remove').hasClass('RemoveButton LanguageRemove');"
            ),
            '1',
            "English notification text has remove button"
        );

        # Set only one language as default.
        $Helper->ConfigSettingChange(
            Key   => 'DefaultUsedLanguages',
            Valid => 1,
            Value => {
                de => 'German',
                en => 'English (United States)'
            },
        );

        # Navigate to AdminNotificationEvent add screen.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminNotificationEvent;Subaction=Add");

        # Check if default English language is shown.
        $Self->Is(
            $Selenium->execute_script(
                "return \$('.NotificationLanguage h2:contains(\"English (United States)\")').text().trim();"
            ),
            'English (United States)',
            "Language box is English (United States)"
        );

        $Selenium->InputFieldValueSet(
            Element => '#Language',
            Value   => 'de',
        );

        # Remove English text notification.
        $Selenium->find_element( ".AdditionalInformation #en_Language_Remove", 'css' )->click();

        $Selenium->WaitFor( AlertPresent => 1 );
        $Selenium->accept_alert();

        # Check if default English language is not shown.
        $Self->Is(
            $Selenium->execute_script(
                "return \$('.NotificationLanguage h2:contains(\"English (United States)\")').length;"
            ),
            0,
            "Language box is English (United States) is removed"
        );

        # Delete notification.
        $NotificationEventObject->NotificationDelete(
            ID     => $NotificationID,
            UserID => 1,
        );
    }

);


$Self->DoneTesting();


