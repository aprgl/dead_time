library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

--============================================================================
--  Dead Time Generation Block
--============================================================================
-- Generate dead time to avoid shoot through caused by high or low side being
-- commanded on before power device has fully turned off.
-- Version: 0.0.0 Initial Commit - haven't even tried to compile -Shaun
-- Version: 0.0.1 Fixed github linter errors - still haven't compiled -Shaun
------------------------------------------------------------------------------

entity dead_time is
	Port (
		rst_n_in		: in 	std_logic;
		clk_in 			: in 	std_logic;
		high_side_in	: in  	std_logic;
		low_side_in		: in  	std_logic;
		dead_time_in	: in 	std_logic_vector(7 downto 0);
		high_side_out	: out 	std_logic;
		low_side_out	: out 	std_logic
	);
end entity dead_time;

architecture rtl of dead_time is
	-- State Machine Signals
	signal dead_time_counter	: std_logic_vector(7 downto 0)  :=  '0';

	-- State Machine Signals
	type state_type is (state_reset,
						state_hold,
						state_standby,
						state_h, 
						state_l);

	signal state, next_state: state_type := state_reset; -- legal?
	
begin

    --========================================================================
    --  State Machine Control
    --========================================================================
    -- State machine control block - reset and next state indexing
    --------------------------------------------------------------------------
	
	-- State machine control block - reset and next state indexing
	state_machine_ctrl: process (rst_n_in, clk_in) begin
		if (rst_n_in = '0') then
			state <= state_reset;  		-- default state on reset
		elsif (rising_edge(sys_clk)) then
			state <= next_state;   		-- clocked change of state
		end if;
	end process state_machine_ctrl;

	-- State machine for our little dead time controller
	state_machine: process (state, 
							dead_time_complete,
							high_side_in,
							low_side_in) begin
		case state is
			-- If we're in a reset state, kill our outputs and assume they were
			-- previously commanded high, so reset our dead time counter to 0.
			when state_reset =>
				high_side_out <= '0';
				low_side_out <= '0';
				next_state <= state_hold;
			
			-- We're ready to start our dead time counter
			when state_hold =>
				high_side_out <= '0';
				low_side_out <= '0';
				if(dead_time_complete = '1') then
					next_state <= state_standby;
				else
					next_state <= state_hold;
				end if;

			-- Ready to drive an output
			when state_standby =>
				high_side_out <= '0';
				low_side_out <= '0';
				if (low_side_in = '1') then
					next_state <= state_l;
				elsif (high_side_in = '1') then
					next_state <= state_h;
				else
					next_state <= state_standby;
				end if;	

			-- Low side is being commanded on and we are not in dead time
			when state_l =>
				high_side_out <= '0';
				low_side_out <= '1';
				if (low_side_in = '1') then
					next_state <= state_l;
				else
					next_state <= state_reset;
				end if;

			-- High side is being commanded on and we are not in dead time
			when state_h =>
				high_side_out <= '1';
				low_side_out <= '0';
				if (high_side_in = '1') then
					next_state <= state_h;
				else
					next_state <= state_reset;
				end if;
		end case;
	end process state_machine;
	
	--========================================================================
    --  Dead Time Counter Logic
    --========================================================================
    -- 
    --------------------------------------------------------------------------
    -- generate the 20kHz Clock
    dead_time_counter_proc: process (state, clk_in) begin
        if (state = state_reset) then
        	dead_time_complete <= '0';
        	dead_time_counter <= (others => '0');
        elsif (rising_edge(clk_in) and (state = state_hold)) then
        	if(dead_time_counter < dead_time_in) then
            	dead_time_counter <= dead_time_counter + 1;
            else
            	dead_time_complete <= '1';
        	end if;
        end if;

    end process dead_time_counter_proc;
    -------------------------------------------------------------------------
    
    --=======================================================================
    --  Stateless Signals
    --=======================================================================
	--pwm_clk_out <= pwm_clk;
  	--uh_out 	<= '1' when clk_cnt > PWM_DUTY else '0';

end architecture rtl;