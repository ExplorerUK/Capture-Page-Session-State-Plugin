CREATE OR REPLACE PACKAGE BODY com_uk_explorer_pss
IS

  g_collection_name    apex_collections.collection_name%TYPE DEFAULT NULL;
  g_check_type_con_c   CONSTANT VARCHAR2(32) DEFAULT 'CONDITION';
  g_check_type_ro_c    CONSTANT VARCHAR2(32) DEFAULT 'READONLY';
  g_check_type_authr_c CONSTANT VARCHAR2(32) DEFAULT 'AUTHORIZATION';
  g_debug_prefix       CONSTANT VARCHAR2(1) DEFAULT '!'; -- See advanced debugging https://bit.ly/APEXTabLock

  lv_fn_get_current_lang VARCHAR2(32767) DEFAULT q'[
  FUNCTION get_current_lang
  RETURN varchar2
  IS
    lv_application_primary_language apex_applications.application_primary_language%TYPE DEFAULT NULL;
  BEGIN
    SELECT application_primary_language
    INTO lv_application_primary_language
    FROM apex_applications
    WHERE application_id = nv('APP_ID');

    RETURN NVL( apex_util.get_session_lang, lv_application_primary_language);
  END get_current_lang;]';


  FUNCTION substitute_component_items(p_string VARCHAR2, p_type VARCHAR2, p_id VARCHAR2, p_name VARCHAR2 )
  RETURN VARCHAR2
  IS
   -- Variables
   l_return          VARCHAR2(32767) DEFAULT p_string;
  BEGIN
    
    l_return := REPLACE( l_return, ':APP_COMPONENT_TYPE', '''' || p_type || '''');
    l_return := REPLACE( l_return, ':APP_COMPONENT_ID', '''' || p_id || '''');
    l_return := REPLACE( l_return, ':APP_COMPONENT_NAME ', '''' || p_name || '''');

    RETURN l_return;
  END substitute_component_items;

  PROCEDURE d(p_message VARCHAR2)
  IS
  BEGIN
    apex_debug.message(g_debug_prefix || p_message);
  END d;

  FUNCTION get_condition_result(  p_condition_type_code                     apex_application_page_items.condition_type_code%TYPE,
                                  p_condition_expression1                   apex_application_page_items.condition_expression1%TYPE,
                                  p_condition_expression2                   apex_application_page_items.condition_expression2%TYPE  )
  RETURN VARCHAR2
  IS
      -- l_plsql_code     CLOB;
      -- l_context        apex_exec.t_context; 
      -- l_t_column       apex_exec.t_column; 
      -- l_sql_parameters apex_exec.t_parameters;
      l_context                 apex_exec.t_context; 
      l_condition               VARCHAR2(5) DEFAULT NULL;
      l_condition_expression1   apex_application_page_items.condition_expression1%TYPE DEFAULT RTRIM( p_condition_expression1, ';');
      -- l_condition_expression1_f apex_application_page_items.condition_expression1%TYPE DEFAULT REPLACE( l_condition_expression1, '''', '''''');
      l_condition_expression2   apex_application_page_items.condition_expression2%TYPE DEFAULT RTRIM( p_condition_expression2, ';');
      -- l_condition_expression2_f apex_application_page_items.condition_expression1%TYPE DEFAULT REPLACE( l_condition_expression2, '''', '''''');
      l_condition_type_code     apex_application_page_items.condition_type_code%TYPE DEFAULT p_condition_type_code;  
      
  BEGIN

    -- Preformat
    CASE 
    WHEN l_condition_type_code = 'REQUEST_EQUALS_CONDITION'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':REQUEST = q''[' || l_condition_expression1 || ']''';
    WHEN l_condition_type_code = 'REQUEST_NOT_EQUAL_CONDITION'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':REQUEST != q''[' || l_condition_expression1 || ']'' OR :REQUEST IS NULL';
    WHEN l_condition_type_code = 'REQUEST_IN_CONDITION'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      -- l_condition_expression1 := 'INSTR(''' || l_condition_expression1_f || ''', :REQUEST ) > 0';
      l_condition_expression1 := 'INSTR( q''[' || l_condition_expression1 || ']'', :REQUEST ) > 0';
    WHEN l_condition_type_code = 'REQUEST_NOT_IN_CONDITION'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := 'INSTR( q''[' || l_condition_expression1 || ']'', :REQUEST ) = 0 OR :REQUEST IS NULL';
    WHEN l_condition_type_code IN ('VAL_OF_ITEM_IN_COND_EQ_COND2', 'NATIVE_ITEM_EQUALS_VALUE' )
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':' || l_condition_expression1 || ' = q''[' || l_condition_expression2 || ']''';
    WHEN l_condition_type_code IN ( 'VAL_OF_ITEM_IN_COND_NOT_EQ_COND2', 'NATIVE_ITEM_NOT_EQUALS_VALUE' )
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':' || l_condition_expression1 || ' != q''[' || l_condition_expression2 || ']''';
    WHEN l_condition_type_code IN ('NATIVE_ITEM_IS_NULL', 'ITEM_IS_NULL')
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':' || l_condition_expression1 || ' IS NULL';
    WHEN l_condition_type_code IN ('NATIVE_ITEM_IS_NOT_NULL', 'ITEM_IS_NOT_NULL')
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':' || l_condition_expression1 || ' IS NOT NULL';
    WHEN l_condition_type_code = 'ITEM_IS_ZERO'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':' || l_condition_expression1 || ' = ''0''';
    WHEN l_condition_type_code = 'ITEM_IS_NOT_ZERO'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':' || l_condition_expression1 || ' != ''0''';
    WHEN l_condition_type_code = 'ITEM_IS_NULL_OR_ZERO'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':' || l_condition_expression1 || ' IS NULL OR :' || l_condition_expression1 || ' = ''0''';
    WHEN l_condition_type_code = 'ITEM_NOT_NULL_OR_ZERO'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':' || l_condition_expression1 || ' IS NOT NULL OR :' || l_condition_expression1 || ' != ''0''';
    WHEN l_condition_type_code = 'ITEM_CONTAINS_NO_SPACES'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':' || l_condition_expression1 || ' IS NULL OR INSTR( :' || l_condition_expression1 || ', '' '') = 0';
    WHEN l_condition_type_code = 'ITEM_IS_NUMERIC'
    THEN
      l_condition_type_code := 'FUNCTION_BODY';
      l_condition_expression1 := 'DECLARE v VARCHAR2(32767) DEFAULT :' || l_condition_expression1 || '; l NUMBER; BEGIN l := TO_NUMBER(v); RETURN TRUE; EXCEPTION WHEN OTHERS THEN RETURN FALSE; END';
    WHEN l_condition_type_code = 'ITEM_IS_NOT_NUMERIC'
    THEN
      l_condition_type_code := 'FUNCTION_BODY';
      l_condition_expression1 := 'DECLARE v VARCHAR2(32767) DEFAULT :' || l_condition_expression1 || '; l NUMBER; BEGIN l := TO_NUMBER(v); RETURN FALSE; EXCEPTION WHEN OTHERS THEN RETURN TRUE; END';
    WHEN l_condition_type_code = 'ITEM_IS_ALPHANUMERIC'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':' || l_condition_expression1 || ' IS NULL OR REGEXP_LIKE(:' || l_condition_expression1 || ', ''^\w+$'')';
    WHEN l_condition_type_code = 'VALUE_OF_ITEM_IN_CONDITION_IN_COLON_DELIMITED_LIST'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := 'apex_plugin_util.get_position_in_list(apex_string.string_to_table(''' || l_condition_expression2 || ''', '':''), :' || l_condition_expression1 || ') > 0';
    WHEN l_condition_type_code = 'VALUE_OF_ITEM_IN_CONDITION_NOT_IN_COLON_DELIMITED_LIST'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := 'NVL(apex_plugin_util.get_position_in_list(apex_string.string_to_table(''' || l_condition_expression2 || ''', '':''), :' || l_condition_expression1 || '), ''0'') = 0';
    WHEN l_condition_type_code IN ( 'USER_PREF_IN_COND_EQ_COND2', 'NATIVE_PREF_EQUALS_VALUE' )
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := 'APEX_UTIL.GET_PREFERENCE(''' || l_condition_expression1 || ''') = ''' || l_condition_expression2 || '''';
    WHEN l_condition_type_code IN ( 'USER_PREF_IN_COND_NOT_EQ_COND2', 'NATIVE_PREF_NOT_EQUALS_VALUE' )
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := 'APEX_UTIL.GET_PREFERENCE(''' || l_condition_expression1 || ''') IS NULL OR APEX_UTIL.GET_PREFERENCE(''' || l_condition_expression1 || ''') != ''' || l_condition_expression2 || '''';
    WHEN l_condition_type_code = 'CURRENT_PAGE_EQUALS_CONDITION'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':APP_PAGE_ID = ' || l_condition_expression1;
    WHEN l_condition_type_code = 'CURRENT_PAGE_NOT_EQUAL_CONDITION'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := ':APP_PAGE_ID != ' || l_condition_expression1;
    WHEN l_condition_type_code = 'CURRENT_PAGE_IN_CONDITION'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := 'apex_plugin_util.get_position_in_list(apex_string.string_to_table(''' || l_condition_expression1 || ''', '',''), :APP_PAGE_ID) > 0';
    WHEN l_condition_type_code = 'CURRENT_PAGE_NOT_IN_CONDITION'
    THEN
      l_condition_type_code := 'PLSQL_EXPRESSION';
      l_condition_expression1 := 'NVL(apex_plugin_util.get_position_in_list(apex_string.string_to_table(''' || l_condition_expression1 || ''', '',''), :APP_PAGE_ID), 0 ) = 0';
    -- TODO: Page/Regions is/not read only
    WHEN l_condition_type_code = 'CURRENT_LANG_EQ_COND1'
    THEN
      l_condition_type_code := 'FUNCTION_BODY';
      l_condition_expression1 := 'DECLARE ' || lv_fn_get_current_lang || ' BEGIN RETURN get_current_lang = ''' || l_condition_expression1 || '''; END';
    WHEN l_condition_type_code = 'CURRENT_LANG_NOT_EQ_COND1'
    THEN
      l_condition_type_code := 'FUNCTION_BODY';
      l_condition_expression1 := 'DECLARE ' || lv_fn_get_current_lang || ' BEGIN RETURN NOT (get_current_lang = ''' || l_condition_expression1 || '''); END';
    WHEN l_condition_type_code = 'CURRENT_LANG_IN_COND1'
    THEN
      l_condition_type_code := 'FUNCTION_BODY';
      l_condition_expression1 := 'DECLARE ' || lv_fn_get_current_lang || ' BEGIN RETURN NVL(INSTR(''' || l_condition_expression1 || ''', get_current_lang ), 0) > 0 ; END';
    WHEN l_condition_type_code = 'CURRENT_LANG_NOT_IN_COND1'
    THEN
      l_condition_type_code := 'FUNCTION_BODY';
      l_condition_expression1 := 'DECLARE ' || lv_fn_get_current_lang || ' BEGIN RETURN NVL(INSTR(''' || l_condition_expression1 || ''', get_current_lang ), 0) = 0 ; END';
    ELSE
      NULL; -- Reformatted/Catch All
    END CASE;

    d('l_condition_expression1: ' || l_condition_expression1);

    CASE 
    WHEN l_condition_type_code = 'PLSQL_EXPRESSION'
    THEN
      l_condition := apex_plugin_util.get_plsql_expression_result( p_plsql_expression => 'apex_debug.tochar(' || l_condition_expression1 || ')');
    WHEN l_condition_type_code IN ( 'FUNCTION_BODY', 'NATIVE_FUNCTION_BODY' )
    THEN
      l_condition := apex_plugin_util.get_plsql_function_result( p_plsql_function => 'DECLARE function xx RETURN BOOLEAN IS BEGIN ' || l_condition_expression1 || '; END xx; BEGIN RETURN apex_debug.tochar(xx); END;');
    WHEN l_condition_type_code IN ('EXISTS', 'NOT_EXISTS', 'NATIVE_EXISTS', 'NATIVE_NOT_EXISTS')
    THEN 
      l_context := apex_exec.open_query_context(
      p_location          => apex_exec.c_location_local_db,
      p_sql_query         => 'select count(*) from sys.dual where exists (' || l_condition_expression1 || ')', 
      p_max_rows         => 1,
      p_total_row_count  => true,
      p_total_row_count_limit => 1 );

      l_condition :=  apex_debug.tochar( (P_CONDITION_TYPE_CODE IN ( 'EXISTS', 'NATIVE_EXISTS' ) and NVL( apex_exec.get_total_row_count( l_context ), 0 ) > 0)  
                                        OR
                                        (P_CONDITION_TYPE_CODE IN ( 'NOT_EXISTS', 'NATIVE_NOT_EXISTS' ) and NVL( apex_exec.get_total_row_count( l_context ), 0 ) = 0) );

      apex_exec.close( l_context );     
    WHEN l_condition_type_code = 'PAGE_IS_IN_PRINTER_FRIENDLY_MODE'
    THEN
      l_condition :=  apex_debug.tochar(APEX_APPLICATION.G_PRINTER_FRIENDLY);
    WHEN l_condition_type_code = 'PAGE_IS_NOT_IN_PRINTER_FRIENDLY_MODE'
    THEN
      l_condition :=  apex_debug.tochar(NOT APEX_APPLICATION.G_PRINTER_FRIENDLY);
    WHEN l_condition_type_code = 'USER_IS_NOT_PUBLIC_USER'
    THEN
       l_condition :=  apex_debug.tochar(APEX_AUTHENTICATION.IS_AUTHENTICATED);
    WHEN l_condition_type_code = 'USER_IS_PUBLIC_USER'
    THEN
       l_condition :=  apex_debug.tochar(NOT APEX_AUTHENTICATION.IS_AUTHENTICATED);
    WHEN l_condition_type_code = 'DISPLAYING_INLINE_VALIDATION_ERRORS'
    THEN
      l_condition :=  apex_debug.tochar(nvl(apex_application.g_inline_validation_error_cnt,0) > 0 );
    WHEN l_condition_type_code = 'NOT_DISPLAYING_INLINE_VALIDATION_ERRORS'
    THEN
      l_condition :=  apex_debug.tochar(nvl(apex_application.g_inline_validation_error_cnt,0) = 0 );
    WHEN l_condition_type_code = 'NEVER'
    THEN
       l_condition :=  'false';
    WHEN l_condition_type_code = 'ALWAYS'
    THEN
       l_condition :=  'true';
    ELSE
      l_condition := 'true';
    END CASE;
  
    RETURN replace(l_condition,'null','false');
  END get_condition_result;

  FUNCTION get_ancestral_condition_result(  p_parent_id   NUMBER,
                                            p_check_type  VARCHAR2 DEFAULT g_check_type_con_c )
  RETURN VARCHAR2
  IS
     l_return   VARCHAR2(5) DEFAULT NULL;
  BEGIN

    <<reverse_ancestral_tree_walk>>
    FOR x IN ( SELECT CASE WHEN p_check_type = g_check_type_con_c THEN C006 
                           WHEN p_check_type = g_check_type_ro_c THEN C007
                           WHEN p_check_type = g_check_type_authr_c THEN C008 
                           ELSE C006 /* Default */
                           END ancestral_condition_result 
                 FROM apex_collections
                WHERE collection_name = g_collection_name
                CONNECT BY PRIOR C002 = C001
                START WITH C001 = p_parent_id
                )
    LOOP
      --  IF p_parent_id = 31574261425866802
      --  THEN
      --   d('>' || p_parent_id);
      --   d('>' || p_check_type);
      --   d('>' || g_check_type_con_c || '>' || g_check_type_ro_c);
      --   d('>' || x.ancestral_condition_result);
      --  END IF;

       IF p_check_type IN (g_check_type_con_c, g_check_type_authr_c) AND x.ancestral_condition_result = 'false'
       THEN
        l_return := 'false';
        EXIT reverse_ancestral_tree_walk;
       ELSIF p_check_type = g_check_type_ro_c AND x.ancestral_condition_result = 'true'
       THEN
        l_return := 'true';
        EXIT reverse_ancestral_tree_walk;
       END IF;
    END LOOP;
    
    -- NULL = No significant ancestral result found
    RETURN l_return;

  END get_ancestral_condition_result;

  PROCEDURE kp_process_page_regions
  IS
    l_condition                 VARCHAR2(5) DEFAULT NULL;
    l_readonly                  VARCHAR2(5) DEFAULT NULL;
    l_authorization             VARCHAR2(5) DEFAULT NULL;
    ln_authorization_scheme_id  apex_application_authorization.authorization_scheme_id%TYPE DEFAULT NULL;
    
  BEGIN
    d('>kp_process_page_regions');
    FOR x in ( select r.* 
                from apex_application_page_regions r 
              where r.application_id = g_app_id_c 
                and r.page_id = g_app_page_id_c
               connect by prior r.region_id = r.parent_region_id 
               start with r.parent_region_id IS NULL 
               order siblings by r.display_sequence, r.template_id )
    LOOP

      -- Get Server-Condition / Read-Only results for each item
      l_condition := NVL( get_ancestral_condition_result( x.parent_region_id, g_check_type_con_c), 
                          get_condition_result( x.condition_type_code, x.condition_expression1, x.condition_expression2 ));
      l_readonly := NVL( get_ancestral_condition_result( x.parent_region_id, g_check_type_ro_c), 
                         apex_debug.tochar(x.read_only_condition_type_code IS NOT NULL AND
                         get_condition_result( x.read_only_condition_type_code, x.read_only_condition_exp1, x.read_only_condition_exp2 )  = 'true' )
                         );

      -- Authorization
      IF x.authorization_scheme_id IS NOT NULL
      THEN        
        d('>Authorization Scheme ID: ' || x.authorization_scheme_id);
        ln_authorization_scheme_id := LTRIM(x.authorization_scheme_id, '!');
        -- Horrific performance when joining to driving cursor. Hence seperate cursor
        FOR z in ( select * 
                     from apex_application_authorization a 
                    where a.application_id = g_app_id_c     
                      and a.authorization_scheme_id = ln_authorization_scheme_id)
        LOOP    
          IF z.caching IN ('BY_COMPONENT','NO_CACHE') 
          THEN
            -- Refetch for (1) Once Per Component and (2) Always (No Caching)     
            -- Prepare Calls - TODO - find a way to set these special items
            z.attribute_01 := substitute_component_items(z.attribute_01, 'APEX_APPLICATION_PAGE_REGIONS', x.region_id, x.region_name );
            z.attribute_02 := substitute_component_items(z.attribute_02, 'APEX_APPLICATION_PAGE_REGIONS', x.region_id, x.region_name );

            l_authorization := NVL( get_ancestral_condition_result( x.parent_region_id, g_check_type_authr_c),
                                    get_condition_result( z.scheme_type_code, z.attribute_01, z.attribute_02 ));
          ELSE
            -- Known result - just fetch
            l_authorization :=  NVL( get_ancestral_condition_result( x.parent_region_id, g_check_type_authr_c),
                                     apex_debug.tochar(apex_authorization.is_authorized( p_authorization_name => z.authorization_scheme_name )));

          END IF;
          IF x.authorization_scheme_id LIKE '!%'
          THEN
            l_authorization := apex_debug.tochar( NOT (l_authorization = 'true' ));
          END IF;
        END LOOP;
      ELSE
         -- No auth scheme. So either fetch ancestral or its enabled
         l_authorization := NVL( get_ancestral_condition_result( x.parent_region_id, g_check_type_authr_c),
                                  'true');
      END IF;             

       apex_collection.add_member(
           p_collection_name => g_collection_name
         , p_c001 =>  x.region_id /* ID */
         , p_c002 => x.parent_region_id /* Parent */
         , p_c003 => 'REGION'
         , p_c004 => x.region_name
         , p_c005 => NULL         
         , p_c006 => l_condition
         , p_c007 => l_readonly
         , p_c008 => l_authorization

       );
      
    END LOOP;
  END kp_process_page_regions;    

  PROCEDURE kp_process_page_items
  IS
    l_condition VARCHAR2(5) DEFAULT NULL;
    l_readonly  VARCHAR2(5) DEFAULT NULL;
  BEGIN
    d('>kp_process_page_items');
    FOR x in ( select * from apex_application_page_items where application_id = g_app_id_c and page_id = g_app_page_id_c ORDER BY display_sequence )
    LOOP
      d('^' || x.item_name );
      -- Get Server-Condition / Read-Only results for each item
      l_condition := NVL( get_ancestral_condition_result( x.region_id, g_check_type_con_c), 
                          get_condition_result( x.condition_type_code, x.condition_expression1, x.condition_expression2 ));
      l_readonly := NVL( get_ancestral_condition_result( x.region_id, g_check_type_ro_c), 
                         apex_debug.tochar(x.read_only_condition_type_code IS NOT NULL AND
                         get_condition_result( x.read_only_condition_type_code, x.read_only_condition_exp1, x.read_only_condition_exp2 )  = 'true' )
                         );

       apex_collection.add_member(
           p_collection_name => g_collection_name
         , p_c001 =>  x.item_id /* ID */
         , p_c002 => x.region_id /* Parent */
         , p_c003 => 'PAGE_ITEM'
         , p_c004 => x.item_name
         , p_c005 => v(x.item_name)
         , p_c006 => l_condition
         , p_c007 => l_readonly

       );
      
    END LOOP;
  END kp_process_page_items;    

  PROCEDURE kp_process_state
  IS 
  begin
    
    d('>kp_process_state');
    apex_collection.create_or_truncate_collection(
        p_collection_name => g_collection_name
    );
    -- Regions
    kp_process_page_regions;
    -- Items
    kp_process_page_items;

    --  apex_util.set_session_state( 'APP_COMPONENT_NAME','P1_SUBBY_3', false);
    --  apex_plugin_util.execute_plsql_code ('DECLARE l BOOLEAN; BEGIN l := ''Component Based Security'):APP_COMPONENT_NAME := ''P1_SUBBY_3''; END;');
--     d('>you');
--     d( apex_debug.tochar(apex_authorization.is_authorized( 'Component Based Security')));


--     d(apex_plugin_util.get_plsql_function_result( p_plsql_function => 'DECLARE function xx RETURN BOOLEAN IS BEGIN ' || 
--     q'[
--         DECLARE
-- BEGIN
-- apex_debug.message('bite');
-- apex_debug.message(:APP_COMPONENT_TYPE);
-- apex_debug.message(:APP_COMPONENT_ID );
-- apex_debug.message(:APP_COMPONENT_NAME);
-- RETURN TRUE;
-- END
-- ]'    
--  || '; END xx; BEGIN RETURN apex_debug.tochar(xx); END;'));



  END kp_process_state;

  function execute
      ( p_process in apex_plugin.t_process
      , p_plugin  in apex_plugin.t_plugin
      )
  return apex_plugin.t_process_exec_result
  as
      l_exec_result apex_plugin.t_process_exec_result;

      -- l_collection_name         varchar2(4000) := p_process.attribute_01;
      -- l_exclude                 varchar2(4000) := p_process.attribute_02; 
  

  begin

      g_collection_name := p_process.attribute_01;

      d('>Page Item Security');
      d('Collection Name: ' || g_collection_name );

      apex_plugin_util.debug_process
          ( p_plugin  => p_plugin
          , p_process => p_process
          );

        kp_process_state;

      return l_exec_result;
  end execute;

END com_uk_explorer_pss;
/
show err