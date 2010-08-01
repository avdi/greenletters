Feature: play adventure
  As a nerd
  I want to play a text adventure game
  Because I'm old-skool

  Scenario: play first few rooms (named process)
    Given process activity is logged to "greenletters.log"
    Given a process "adventure" from command "adventure"
    Given I reply "no" to output "Would you like instructions?" from process "adventure"
    Given I reply "yes" to output "Do you really want to quit" from process "adventure"
    When I execute the process "adventure"
    Then I should see the following output from process "adventure":
    """
    You are standing at the end of a road before a small brick building.
    Around you is a forest.  A small stream flows out of the building and
    down a gully.
    """
    When I enter "east" into process "adventure"
    Then I should see the following output from process "adventure":
    """
    You are inside a building, a well house for a large spring.
    """
    When I enter "west" into process "adventure"
    Then I should see the following output from process "adventure":
    """
    You're at end of road again.
    """
    When I enter "south" into process "adventure"
    Then I should see the following output from process "adventure":
    """
    You are in a valley in the forest beside a stream tumbling along a
    rocky bed.
    """
    When I enter "quit" into process "adventure"
    Then the process "adventure" should exit succesfully

  Scenario: play first few rooms (default process)
    Given process activity is logged to "greenletters.log"
    Given a process from command "adventure"
    Given I reply "no" to output "Would you like instructions?"
    Given I reply "yes" to output "Do you really want to quit"
    When I execute the process
    Then I should see the following output:
    """
    You are standing at the end of a road before a small brick building.
    Around you is a forest.  A small stream flows out of the building and
    down a gully.
    """
    When I enter "east"
    Then I should see the following output:
    """
    You are inside a building, a well house for a large spring.
    """
    When I enter "west"
    Then I should see the following output:
    """
    You're at end of road again.
    """
    When I enter "south"
    Then I should see the following output:
    """
    You are in a valley in the forest beside a stream tumbling along a
    rocky bed.
    """
    When I enter "quit"
    Then the process should exit succesfully


