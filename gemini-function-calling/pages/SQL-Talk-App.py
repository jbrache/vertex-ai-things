# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import time
import requests
import os

LOCATION = "us-central1"  # @param {type:"string"}
PROJECT_ID_DATASET = 'bigquery-public-data'
DATASET_ID_NAME = 'thelook_ecommerce'

# os.environ["GOOGLE_CLOUD_QUOTA_PROJECT"] = PROJECT_ID_QUOTA  # @param {type:"string"}
bq_public_datasets = ['america_health_rankings', 'austin_311', 'austin_bikeshare', 'austin_crime', 'austin_incidents', 'austin_waste', 'baseball', 'bbc_news', 'bigqueryml_ncaa', 'bitcoin_blockchain', 'blackhole_database', 'blockchain_analytics_ethereum_mainnet_us', 'bls', 'bls_qcew', 'breathe', 'broadstreet_adi', 'catalonian_mobile_coverage', 'catalonian_mobile_coverage_eu', 'census_bureau_acs', 'census_bureau_construction', 'census_bureau_international', 'census_bureau_usa', 'census_opportunity_atlas', 'census_utility', 'cfpb_complaints', 'chicago_crime', 'chicago_taxi_trips', 'clemson_dice', 'cloud_storage_geo_index', 'cms_codes', 'cms_medicare', 'cms_synthetic_patient_data_omop', 'country_codes', 'covid19_aha', 'covid19_covidtracking', 'covid19_ecdc', 'covid19_ecdc_eu', 'covid19_genome_sequence', 'covid19_geotab_mobility_impact', 'covid19_geotab_mobility_impact_eu', 'covid19_google_mobility', 'covid19_google_mobility_eu', 'covid19_govt_response', 'covid19_italy', 'covid19_italy_eu', 'covid19_jhu_csse', 'covid19_jhu_csse_eu', 'covid19_nyt', 'covid19_open_data', 'covid19_open_data_eu', 'covid19_public_forecasts', 'covid19_public_forecasts_asia_ne1', 'covid19_rxrx19', 'covid19_symptom_search', 'covid19_tracking', 'covid19_usafacts', 'covid19_vaccination_access', 'covid19_vaccination_search_insights', 'covid19_weathersource_com', 'crypto_band', 'crypto_bitcoin', 'crypto_bitcoin_cash', 'crypto_dash', 'crypto_dogecoin', 'crypto_ethereum', 'crypto_ethereum_classic', 'crypto_iotex', 'crypto_kusama', 'crypto_litecoin', 'crypto_polkadot', 'crypto_polygon', 'crypto_tezos', 'crypto_theta', 'crypto_zcash', 'crypto_zilliqa', 'cymbal_investments', 'dataflix_covid', 'dataflix_traffic_safety', 'deepmind_alphafold', 'deps_dev_v1', 'dimensions_ai_covid19', 'ebi_chembl', 'ebi_surechembl', 'eclipse_megamovie', 'epa_historical_air_quality', 'ethereum_blockchain', 'etsi_technical_standards', 'faa', 'fcc_political_ads', 'fda_drug', 'fda_food', 'fdic_banks', 'fec', 'fhir_synthea', 'ga4_obfuscated_sample_ecommerce', 'gbif', 'gdelt_hathitrustbooks', 'gdelt_internetarchivebooks', 'genomics_cannabis', 'genomics_rice', 'geo_census_blockgroups', 'geo_census_tracts', 'geo_international_ports', 'geo_openstreetmap', 'geo_us_boundaries', 'geo_us_census_places', 'geo_us_roads', 'geo_whos_on_first', 'ghcn_d', 'ghcn_m', 'github_repos', 'gnomAD', 'gnomAD_asiane1', 'gnomAD_eu', 'goog_blockchain_ethereum_mainnet_us', 'google_ads', 'google_ads_geo_mapping_asia_east1', 'google_ads_geo_mapping_asia_east2', 'google_ads_geo_mapping_asia_northeast1', 'google_ads_geo_mapping_asia_northeast2', 'google_ads_geo_mapping_asia_northeast3', 'google_ads_geo_mapping_asia_south1', 'google_ads_geo_mapping_asia_south2', 'google_ads_geo_mapping_asia_southeast1', 'google_ads_geo_mapping_asia_southeast2', 'google_ads_geo_mapping_australia_southeast1', 'google_ads_geo_mapping_australia_southeast2', 'google_ads_geo_mapping_eu', 'google_ads_geo_mapping_europe_central2', 'google_ads_geo_mapping_europe_north1', 'google_ads_geo_mapping_europe_southwest1', 'google_ads_geo_mapping_europe_west1', 'google_ads_geo_mapping_europe_west2', 'google_ads_geo_mapping_europe_west3', 'google_ads_geo_mapping_europe_west4', 'google_ads_geo_mapping_europe_west6', 'google_ads_geo_mapping_europe_west8', 'google_ads_geo_mapping_europe_west9', 'google_ads_geo_mapping_me_west1', 'google_ads_geo_mapping_northamerica_northeast1', 'google_ads_geo_mapping_northamerica_northeast2', 'google_ads_geo_mapping_southamerica_east1', 'google_ads_geo_mapping_southamerica_west1', 'google_ads_geo_mapping_us', 'google_ads_geo_mapping_us_central1', 'google_ads_geo_mapping_us_east1', 'google_ads_geo_mapping_us_east4', 'google_ads_geo_mapping_us_east5', 'google_ads_geo_mapping_us_south1', 'google_ads_geo_mapping_us_west1', 'google_ads_geo_mapping_us_west2', 'google_ads_geo_mapping_us_west3', 'google_ads_geo_mapping_us_west4', 'google_ads_transparency_center', 'google_analytics_sample', 'google_books_ngrams_2020', 'google_cfe', 'google_cloud_release_notes', 'google_dei', 'google_patents_research', 'google_political_ads', 'google_trends', 'grid_ac', 'hacker_news', 'hud_zipcode_crosswalk', 'human_genome_variants', 'human_variant_annotation', 'idc_current', 'idc_current_clinical', 'idc_v1', 'idc_v10', 'idc_v11', 'idc_v11_clinical', 'idc_v12', 'idc_v12_clinical', 'idc_v13', 'idc_v13_clinical', 'idc_v14', 'idc_v14_clinical', 'idc_v15', 'idc_v15_clinical', 'idc_v2', 'idc_v3', 'idc_v4', 'idc_v5', 'idc_v6', 'idc_v7', 'idc_v8', 'idc_v9', 'imdb', 'immune_epitope_db', 'iowa_liquor_sales', 'iowa_liquor_sales_forecasting', 'irs_990', 'labeled_patents', 'libraries_io', 'listenbrainz', 'london_bicycles', 'london_crime', 'london_fire_brigade', 'marec', 'medicare', 'ml_datasets', 'ml_datasets_uscentral1', 'modis_terra_net_primary_production', 'moon_phases', 'multilingual_spoken_words_corpus', 'nasa_wildfire', 'ncaa_basketball', 'nces_ipeds', 'new_york', 'new_york_311', 'new_york_citibike', 'new_york_mv_collisions', 'new_york_subway', 'new_york_taxi_trips', 'new_york_trees', 'news_hatecrimes', 'nhtsa_traffic_fatalities', 'nih_gudid', 'nih_sequence_read', 'nlm_rxnorm', 'noaa_global_forecast_system', 'noaa_goes16', 'noaa_goes17', 'noaa_gsod', 'noaa_historic_severe_storms', 'noaa_hurricanes', 'noaa_icoads', 'noaa_lightning', 'noaa_nwm', 'noaa_passive_acoustic_index', 'noaa_passive_bioacoustic', 'noaa_pifsc_metadata', 'noaa_preliminary_severe_storms', 'noaa_significant_earthquakes', 'noaa_tsunami', 'nppes', 'nrel_nsrdb', 'open_buildings', 'open_images', 'open_targets_genetics', 'open_targets_platform', 'openaq', 'patents', 'patents_cpc', 'patents_dsep', 'patents_view', 'persistent_udfs', 'properati_properties_ar', 'properati_properties_br', 'properati_properties_cl', 'properati_properties_co', 'properati_properties_mx', 'properati_properties_pe', 'properati_properties_uy', 'pypi', 'samples', 'san_francisco', 'san_francisco_311', 'san_francisco_bikeshare', 'san_francisco_film_locations', 'san_francisco_neighborhoods', 'san_francisco_sffd_service_calls', 'san_francisco_sfpd_incidents', 'san_francisco_transit_muni', 'san_francisco_trees', 'sdoh_bea_cainc30', 'sdoh_cdc_wonder_natality', 'sdoh_cms_dual_eligible_enrollment', 'sdoh_hrsa_shortage_areas', 'sdoh_hud_housing', 'sdoh_hud_pit_homelessness', 'sdoh_snap_enrollment', 'sec_quarterly_financials', 'stackoverflow', 'sunroof_solar', 'the_general_index', 'the_met', 'thelook_ecommerce', 'ucb_fung_patent_data', 'umiami_lincs', 'un_sdg', 'us_res_real_est_data', 'usa_contagious_disease', 'usa_names', 'usda_nass_agriculture', 'usfs_fia', 'usitc_investigations', 'uspto_oce_assignment', 'uspto_oce_cancer', 'uspto_oce_claims', 'uspto_oce_litigation', 'uspto_oce_office_actions', 'uspto_oce_pair', 'uspto_ptab', 'utility_eu', 'utility_us', 'wikipedia', 'wise_all_sky_data_release', 'world_bank_global_population', 'world_bank_health_population', 'world_bank_intl_debt', 'world_bank_intl_education', 'world_bank_wdi', 'worldbank_wdi', 'worldpop']
bq_public_datasets = ['thelook_ecommerce']

from google.cloud import bigquery
import streamlit as st
from vertexai.generative_models import FunctionDeclaration, GenerativeModel, Part, Tool

# ----------- Datasets -----------
list_datasets_func = FunctionDeclaration(
    name="list_datasets",
    description="Get a list of datasets that will help answer the user's question",
    parameters={
        "type": "object",
        "properties": {},
    },
)
list_tables_func = FunctionDeclaration(
    name="list_tables",
    description="List tables in a dataset that will help answer the user's question",
    parameters={
        "type": "object",
        "properties": {
            "dataset_id": {
                "type": "string",
                "description": "Fully qualified ID of the dataset to fetch tables from. Always use the fully qualified dataset and table names.",
            }
        },
        "required": [
            "dataset_id",
        ],
    },
)
get_table_func = FunctionDeclaration(
    name="get_table",
    description="Get information about a table, including the description, schema, and number of rows that will help answer the user's question. Always use the fully qualified dataset and table names.",
    parameters={
        "type": "object",
        "properties": {
            "table_id": {
                "type": "string",
                "description": "Fully qualified ID of the table to get information about.",
            }
        },
        "required": [
            "table_id",
        ],
    },
)
sql_query_func = FunctionDeclaration(
    name="sql_query",
    description="Get information from data in BigQuery using SQL queries",
    parameters={
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "SQL query on a single line that will help give quantitative answers to the user's question when run on a BigQuery dataset and table. In the SQL query, always use the fully qualified dataset and table names.",
            }
        },
        "required": [
            "query",
        ],
    },
)

sql_query_dry_run_func = FunctionDeclaration(
    name="sql_query_dry_run",
    description="Run a dry run SQL query to get information from data in BigQuery using SQL queries. Query Dry Run demonstrates issuing a dry run query to validate query structure and provide an estimate of the bytes scanned. Use this tool to estimate the number of bytes that will be processed when executing a query.",
    parameters={
        "type": "object",
        "properties": {
            "dry_run_query": {
                "type": "string",
                "description": "SQL query on a single line that will help give quantitative answers to the user's question when run on a BigQuery dataset and table. In the SQL query, always use the fully qualified dataset and table names.",
            }
        },
        "required": [
            "dry_run_query",
        ],
    },
)

# ----------------------------------

st.set_page_config(
    page_title="SQL Talk with BigQuery",
    page_icon="vertex-ai.png",
    layout="wide",
)
col1, col2 = st.columns([8, 1])
with col1:
    st.title("SQL Talk with BigQuery")
with col2:
    st.image("vertex-ai.png")
st.subheader("Powered by Function Calling in Gemini")
st.markdown(
    "[Source Code](https://github.com/GoogleCloudPlatform/generative-ai/tree/main/gemini/function-calling/sql-talk-app/)   •   [Documentation](https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/function-calling)   •   [Codelab](https://codelabs.developers.google.com/codelabs/gemini-function-calling)   •   [Sample Notebook](https://github.com/GoogleCloudPlatform/generative-ai/blob/main/gemini/function-calling/intro_function_calling.ipynb)"
)

def on_change_checkbox(filter_id):
    print(filter_id)

with st.sidebar:
    dataset_option = st.selectbox(
        'Which BigQuery Public Dataset would you like to query?',
        options = ['thelook_ecommerce'])
    
    sql_tool_checkbox = st.checkbox("SQL Functions", value=True, help="Test responses with/without function calling")

    temperature = st.slider(
        'Temperature', 
        0.0, 1.0, 0.0,
        help="The temperature is used for sampling during the response generation, which occurs when topP and topK are applied. Temperature controls the degree of randomness in token selection. Lower temperatures are good for prompts that require a more deterministic and less open-ended or creative response, while higher temperatures can lead to more diverse or creative results. A temperature of 0 is deterministic: the highest probability response is always selected."
    )

    # max_tokens = st.slider(
    #     'Max Tokens', 
    #     5, 1000, 500, 
    #     help="Max response length. Together with your prompt, it shouldn't surpass the model's token limit (2048)"
    # )

    # top_p = st.slider(
    # 'Top P', 
    # 0.0, 1.0, 0.9, 0.01, 
    # help="Adjusts output diversity. Higher values consider more tokens; e.g., 0.8 chooses from the top 80% likely tokens."
    # )

if sql_tool_checkbox:
    all_tools = Tool(
        function_declarations=[
            # list_datasets_func,
            list_tables_func,
            get_table_func,
            sql_query_func,
            sql_query_dry_run_func,
        ],
    )
else:
    all_tools = None

# ----------------------------------
if all_tools:
    model = GenerativeModel(
        "gemini-1.0-pro",
        generation_config={"temperature": temperature},
        tools=[all_tools],
    )
else:
    model = GenerativeModel(
        "gemini-1.0-pro",
        generation_config={"temperature": temperature},
    )

with st.expander("Sample prompts", expanded=True):
    st.write(
        """
        SQL Tool
        - What kind of information is in this database?
        - What percentage of orders are returned?
        - How is inventory distributed across our regional distribution centers?
        - Do customers typically place more than one order?
        - Which product categories have the highest profit margins?

        SQL Tool with Dry Run
        - How many bytes will be processed when looking at which product categories have the highest profit margins?
    """
    )
if "messages" not in st.session_state:
    st.session_state.messages = []
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"].replace("$", "\$"))  # noqa: W605
        try:
            with st.expander("Function calls, parameters, and responses"):
                st.markdown(message["backend_details"])
        except KeyError:
            pass
if prompt := st.chat_input("Ask me about information in the database..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)
    with st.chat_message("assistant"):
        message_placeholder = st.empty()
        full_response = ""
        chat = model.start_chat()
        client = bigquery.Client()
        if sql_tool_checkbox:
            prompt += """
                Please give a concise, high-level summary followed by detail in
                plain language about where the information in your response is
                coming from in the database. Only use information that you learn
                from BigQuery, do not make up information.

                Use the format project_name.dataset_name.table_name to fully qualify the ID of a table when using GoogleSQL for queries.

                Use the following context to query from the BigQuery database:
                {
                    "project_name": "INSERT_PROJECT_ID",
                    "description": "Unique ID string used to fully qualify dataset and table IDs.",
                    "datasets": [
                        {
                            "dataset_id": "INSERT_FULL_DATASET_ID",
                            "description": "Fully qualified ID of the dataset to fetch tables from. Always use the fully qualified dataset and table names.",
                        }
                    ]
                }

                Before running queries, get the table using the fully qualified table ID to make sure the query references the right columns.
                """
            dataset_id = f'{PROJECT_ID_DATASET}.{dataset_option}'
            prompt = prompt.replace('INSERT_PROJECT_ID', PROJECT_ID_DATASET)
            prompt = prompt.replace('INSERT_FULL_DATASET_ID', dataset_id)
        print(prompt)
        response = chat.send_message(prompt)
        response = response.candidates[0].content.parts[0]
        print(response)
        api_requests_and_responses = []
        backend_details = ""
        function_calling_in_process = True
        while function_calling_in_process:
            try:
                params = {}
                for key, value in response.function_call.args.items():
                    params[key] = value
                print(response.function_call.name)
                print(params)
                if response.function_call.name == "list_datasets":
                    api_response = client.list_datasets()
                    api_response = str([dataset.dataset_id for dataset in api_response])
                    api_requests_and_responses.append(
                        [response.function_call.name, params, api_response]
                    )
                if response.function_call.name == "list_tables":
                    api_response = client.list_tables(params["dataset_id"])
                    # api_response = str([table.table_id for table in api_response])
                    dataset_id = f'{PROJECT_ID_DATASET}.{dataset_option}.'
                    api_response = str([dataset_id + table.table_id for table in api_response])
                    print(api_response)
                    api_requests_and_responses.append(
                        [response.function_call.name, params, api_response]
                    )
                if response.function_call.name == "get_table":
                    api_response = client.get_table(params["table_id"])
                    api_response = api_response.to_api_repr()
                    api_requests_and_responses.append(
                        [
                            response.function_call.name,
                            params,
                            [
                                str(api_response.get("description", "")),
                                str(
                                    [
                                        column["name"]
                                        for column in api_response["schema"]["fields"]
                                    ]
                                ),
                            ],
                        ]
                    )
                    api_response = str(api_response)
                if response.function_call.name == "sql_query":
                    job_config = bigquery.QueryJobConfig(
                        maximum_bytes_billed=100000000
                    )  # Data limit per query job
                    query_job = client.query(params["query"], job_config=job_config)
                    api_response = query_job.result()
                    api_response = str([dict(row) for row in api_response])
                    api_requests_and_responses.append(
                        [response.function_call.name, params, api_response]
                    )
                if response.function_call.name == "sql_query_dry_run":
                    job_config = bigquery.QueryJobConfig(dry_run=True, use_query_cache=False)
                    print(params["dry_run_query"])
                    query_job = client.query(params["dry_run_query"], job_config=job_config)
                    # api_response = query_job.result()
                    # api_response = str([dict(row) for row in api_response])
                    # A dry run query completes immediately.
                    api_response = f"This query will process {query_job.total_bytes_processed} bytes."
                    api_requests_and_responses.append(
                        [response.function_call.name, params, api_response]
                    )
                print(api_response)
                response = chat.send_message(
                    Part.from_function_response(
                        name=response.function_call.name,
                        response={
                            "content": api_response,
                        },
                    ),
                )
                response = response.candidates[0].content.parts[0]
                backend_details += "- Function call:\n"
                backend_details += (
                    "   - Function name: ```"
                    + str(api_requests_and_responses[-1][0])
                    + "```"
                )
                backend_details += "\n\n"
                backend_details += (
                    "   - Function parameters: ```"
                    + str(api_requests_and_responses[-1][1])
                    + "```"
                )
                backend_details += "\n\n"
                backend_details += (
                    "   - API response: ```"
                    + str(api_requests_and_responses[-1][2])
                    + "```"
                )
                backend_details += "\n\n"
                with message_placeholder.container():
                    st.markdown(backend_details)
            except AttributeError:
                function_calling_in_process = False
        time.sleep(3)
        full_response = response.text
        with message_placeholder.container():
            st.markdown(full_response.replace("$", "\$"))  # noqa: W605
            with st.expander("Function calls, parameters, and responses:"):
                st.markdown(backend_details)
        st.session_state.messages.append(
            {
                "role": "assistant",
                "content": full_response,
                "backend_details": backend_details,
            }
        )
def clear_chat_history():
    st.session_state.messages = [{"role": "assistant", "content": "How may I assist you today?"}]
    
st.sidebar.button('Clear Chat History', on_click=clear_chat_history)