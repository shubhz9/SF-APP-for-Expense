/**
 * Copyright (c), FinancialForce.com, inc
 * Copyright (c) 2022, Deloitte NL
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, 
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice, 
 *      this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice, 
 *      this list of conditions and the following disclaimer in the documentation 
 *      and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors 
 *      may be used to endorse or promote products derived from this software without 
 *      specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/**
 * Class providing common database query support for abstracting and encapsulating query logic.
 * Inherits sharing, allowing extending-selectors to control whether SObjectDescribe runs in system (without) or user (with) mode.
 * Enabling to (opt.) bypass unavailable SObjectTypes like AccountTeamMembers for Community Licenses (do align with Project Salesforce Success Manager).
 * Note, SObjectSelector is an abstract class with no queries being performed, so no regression data vulnerability are expected.
 * To still run those queries WithSharing one can construct a WithSharing InnerClass (like normally done to partially run WithoutSharing)
 */
public abstract class fflib_SObjectSelector implements fflib_ISObjectSelector{

    /**
     * Indicates whether the sObject has the currency ISO code field for organisations which have multi-currency
     * enabled. 
     */
    private Boolean CURRENCY_ISO_CODE_ENABLED{
        get{
            if( CURRENCY_ISO_CODE_ENABLED == null ){
                CURRENCY_ISO_CODE_ENABLED = describeWrapper.getFieldsMap().keySet().contains( 'currencyisocode' );
            }
            return CURRENCY_ISO_CODE_ENABLED;
        }
        set;
    }

    /**
     * Should this selector automatically include the FieldSet fields when building queries?
     */
    private Boolean m_includeFieldSetFields = false;

    /**
     * Should this selector automatically include the related FieldSet fields when building queries?
     */
    private Boolean m_includeRelatedFieldSetFields = false;

    /**
     * Enforce FLS Security
     */
    private Boolean m_enforceFLS = false;

    /**
     * Enforce CRUD Security
     */
    private Boolean m_enforceCRUD = false;

    /**
     * Order by field
     */
    private String m_orderBy;

    /**
     * Sort the query fields in the select statement (defaults to true, at the expense of performance).
     * Switch this off if you need more performant queries.
     */
    private Boolean m_sortSelectFields = true;

    /**
     * Describe helper
     */
    private fflib_SObjectDescribe describeWrapper{
        get{
            if( describeWrapper == null ){
                describeWrapper = fflib_SObjectDescribe.getDescribe( getSObjectType() );
            }
            return describeWrapper;
        }
        set;
    }

    /**
     * Static variables
     */
    private static String DEFAULT_SORT_FIELD = 'CreatedDate';
    private static String SF_ID_FIELD = 'Id';

    /**
     * Implement this method to inform the base class of the SObject (custom or standard) to be queried
     */
    abstract Schema.SObjectType getSObjectType();

    /**
     * Implement this method to inform the base class of the common fields to be queried or listed by the base class methods
     */
    abstract List<Schema.SObjectField> getSObjectFieldList();

    /**
     * Allows selectors to select fields from related sObjects. Similar to getSObjectFieldList(), it works
     * with strings to be able to traverse through relationships.
     *
     * @return  Set of strings containing individual related field paths.
     */
    protected virtual Set<String> getRelatedFieldSet(){
        return new Set<String>();
    }

    /**
     * Constructs the Selector with the default settings
     */
    public fflib_SObjectSelector(){}

    /**
     * Constructs the Selector. It enforces CRUD security by default.
     *
     * @param   includeFieldSetFields   Set to true if the Selector queries are to include Fieldset fields as well 
     */
    public fflib_SObjectSelector( Boolean includeFieldSetFields ){
        this( includeFieldSetFields, true, false, false, false );
    }

    /**
     * Constructs the Selector. It sorts selected fields by default.
     *
     * @param   includeFieldSetFields   Set to true if the Selector queries are to include Fieldset fields as well 
     * @param   enforceCRUD             Enforce CRUD security
     * @param   enforceFLS              Enforce Field Level Security
     */
    public fflib_SObjectSelector( Boolean includeFieldSetFields, Boolean enforceCRUD, Boolean enforceFLS ){
        this( includeFieldSetFields, enforceCRUD, enforceFLS, true, false );
    }

    /**
     * Constructs the Selector.
     *
     * @param   includeFieldSetFields           Set to true if the Selector queries are to include Fieldset fields as well
     * @param   enforceCRUD                     Enforce CRUD security
     * @param   enforceFLS                      Enforce Field Level Security
     * @param   sortSelectFields                Set to false if selecting many columns to skip sorting select fields and improve performance
     * @param   includeRelatedFieldSetFields    Set to true if the Selector queries are to include related Fieldset fields as well
     */
    public fflib_SObjectSelector( Boolean includeFieldSetFields, Boolean enforceCRUD, Boolean enforceFLS, Boolean sortSelectFields, Boolean includeRelatedFieldSetFields ){
        m_includeFieldSetFields = includeFieldSetFields;
        m_enforceCRUD = enforceCRUD;
        m_enforceFLS = enforceFLS;
        m_sortSelectFields = sortSelectFields;
        m_includeRelatedFieldSetFields = includeRelatedFieldSetFields;
    }

    /**
     * Override this method to provide a list of FieldSets that can optionally drive inclusion of additional fields in the base queries
     */
    public virtual List<Schema.FieldSet> getSObjectFieldSetList(){
        return null;
    }

    /**
     * Override this method to control the default ordering of records returned by the base queries,
     * defaults to the name field of the object if it is not encrypted or CreatedDate if there the object has createdDated or Id.
     * 
     * @return  String representing the ordering of records to include in base queries.
     */
    public virtual String getOrderBy(){
        if( m_orderBy == null ){
            Schema.SObjectField nameField = describeWrapper.getNameField();
            if( nameField != null && !nameField.getDescribe().isEncrypted() ){
                m_orderBy = nameField.getDescribe().getName();
            } else{
                m_orderBy = DEFAULT_SORT_FIELD;
                try{
                    if( describeWrapper.getField( m_orderBy ) == null ){
                        m_orderBy = SF_ID_FIELD;
                    }
                } catch( fflib_QueryFactory.InvalidFieldException ex ){
                    m_orderBy = SF_ID_FIELD;
                }
            }
        }
        return m_orderBy;
    }


    /**
     * @description Set the selector to enforce FLS Security.
     */
    public fflib_SObjectSelector enforceFLS(){
        m_enforceFLS = true;
        return this;
    }

    /**
     * @description Set the selector to automatically include the FieldSet fields when building queries.
     */
    public fflib_SObjectSelector includeFieldSetFields(){
        this.m_includeFieldSetFields = true;
        return this;
    }

    /**
     * @description Set the selector to automatically include the related FieldSet fields when building queries.
     */
    public fflib_SObjectSelector includeRelatedFieldSetFields(){
        this.m_includeRelatedFieldSetFields = true;
        return this;
    }

    /**
     * @description Set the selector to ignore CRUD security.
     */
    public fflib_SObjectSelector ignoreCRUD(){
        this.m_enforceCRUD = false;
        return this;
    }

    public fflib_SObjectSelector unsortedSelectFields(){
        this.m_sortSelectFields = false;
        return this;
    }

    /**
     * Returns True if this Selector instance has been instructed by the caller to include Field Set fields.
     */
    public Boolean isIncludeFieldSetFields(){
        return m_includeFieldSetFields;
    }

    /**
     * Returns True if this Selector instance has been instructed by the caller to include related Field Set fields.
     */
    public Boolean isIncludeRelatedFieldSetFields(){
        return m_includeRelatedFieldSetFields;
    }

    /**
     * Returns True if this Selector is enforcing FLS.
     */
    public Boolean isEnforcingFLS(){
        return m_enforceFLS;
    }

    /**
     * Returns True if this Selector is enforcing CRUD Security.
     */
    public Boolean isEnforcingCRUD(){
        return m_enforceCRUD;
    }

    /**
     * Returns True if this Selector is sorting selected fields.
     */
    public Boolean isSortingSelectedFields(){
        return m_sortSelectFields;
    }

    /**
     * Returns the string representation of the SObject this selector represents.
     */
    public String getSObjectName(){
        return describeWrapper.getDescribe().getName();
    }

    /**
     * Performs a SOQL query, 
     *   - Selecting the fields described via getSObjectFieldsList and getSObjectFieldSetList (if included) 
     *   - From the SObject described by getSObjectType
     *   - Where the Id's match those provided in the set
     *   - Ordered by the fields returned via getOrderBy
     *   
     * @return  A list of SObject's.
     */
    public virtual List<SObject> selectSObjectsById( Set<Id> idSet ){
        return Database.query( buildQuerySObjectById() );
    }

    /**
     * Performs a SOQL query, 
     *   - Selecting the fields described via getSObjectFieldsList and getSObjectFieldSetList (if included) 
     *   - From the SObject described by getSObjectType
     *   - Where the Id's match those provided in the set
     *   - Ordered by the fields returned via getOrderBy
     *
     * @return  A QueryLocator (typically for use in a Batch Apex job).
     */
    public virtual Database.QueryLocator queryLocatorById( Set<Id> idSet ){
        return Database.getQueryLocator( buildQuerySObjectById() );
    }

    /**
     * Public access for the getSObjectType during Mock registration
     *   (adding public to the existing method broken base class API backwards compatibility)
     */
    public SObjectType getSObjectType2(){
        return getSObjectType();
    }

    /**
     * Public access for the getSObjectType during Mock registration
     *   (adding public to the existing method broken base class API backwards compatibility)
     */
    public SObjectType sObjectType(){
        return getSObjectType();
    }

    /**
     * Return a QueryFactory configured with the Selectors object, fields, fieldsets and default order by.
     */
    public fflib_QueryFactory newQueryFactory(){
        return newQueryFactory( m_enforceCRUD, m_enforceFLS, true, m_includeRelatedFieldSetFields );
    }

    /**
     * Return a QueryFactory configured with the Selectors object, fields, fieldsets and default order by.
     */
    public fflib_QueryFactory newQueryFactory( Boolean includeSelectorFields ){
        return newQueryFactory( m_enforceCRUD, m_enforceFLS, includeSelectorFields, m_includeRelatedFieldSetFields );
    }

    /**
     * Return a QueryFactory configured with the Selectors object, fields, fieldsets and default order by
     * CRUD and FLS read security will be checked if the corresponding inputs are true (overrides that defined in the selector).
     */
    public fflib_QueryFactory newQueryFactory( Boolean assertCRUD, Boolean enforceFLS, Boolean includeSelectorFields ){
        // Construct QueryFactory around the given SObject
        return configureQueryFactory(
            new fflib_QueryFactory( getSObjectType2() ), assertCRUD, enforceFLS, includeSelectorFields, m_includeRelatedFieldSetFields
        );
    }

    /**
     * Return a QueryFactory configured with the Selectors object, fields, fieldSets, related fieldSets and default order by
     * CRUD and FLS read security will be checked if the corresponding inputs are true (overrides that defined in the selector).
     */
    public fflib_QueryFactory newQueryFactory( Boolean assertCRUD, Boolean enforceFLS, Boolean includeSelectorFields, Boolean includeRelatedFieldSetFields ){
        // Construct QueryFactory around the given SObject
        return configureQueryFactory(
            new fflib_QueryFactory( getSObjectType2() ), assertCRUD, enforceFLS, includeSelectorFields, includeRelatedFieldSetFields
        );
    }

    /**
     * Adds the selectors fields to the given QueryFactory using the given relationship path as a prefix
     *
     * // TODO: This should be consistent (ideally) with configureQueryFactory below
     */
    public void configureQueryFactoryFields( fflib_QueryFactory queryFactory, String relationshipFieldPath ){
        // Add fields from selector prefixing the relationship path
        for( SObjectField field : getSObjectFieldList() ){
            queryFactory.selectField( relationshipFieldPath + '.' + field.getDescribe().getName() );
        }
        for( String field : getRelatedFieldSet() ){
            queryFactory.selectField( relationshipFieldPath + '.' + field );
        }
        // Automatically select the CurrencyIsoCode for MC orgs (unless the object is a known exception to the rule)
        if( UserInfo.isMultiCurrencyOrganization() && CURRENCY_ISO_CODE_ENABLED ){
            queryFactory.selectField( relationshipFieldPath + '.CurrencyIsoCode' );
        }
    }

    /**
     * Adds a subselect QueryFactory based on this selector to the given QueryFactor, return the parentQueryFactory.
     */
    public fflib_QueryFactory addQueryFactorySubselect( fflib_QueryFactory parentQueryFactory ){
        return addQueryFactorySubselect( parentQueryFactory, true );
    }

    /**
     * Adds a subselect QueryFactory based on this selector to the given QueryFactor.
     */
    public fflib_QueryFactory addQueryFactorySubselect( fflib_QueryFactory parentQueryFactory, Boolean includeSelectorFields ){
        fflib_QueryFactory subSelectQueryFactory = parentQueryFactory.subselectQuery( getSObjectType2() );
        return configureQueryFactory( subSelectQueryFactory, m_enforceCRUD, m_enforceFLS, includeSelectorFields, m_includeRelatedFieldSetFields );
    }

    /**
     * Adds a subselect QueryFactory based on this selector to the given QueryFactor.
     */
    public fflib_QueryFactory addQueryFactorySubselectNoAccess( fflib_QueryFactory parentQueryFactory ){
        fflib_QueryFactory subSelectQueryFactory = parentQueryFactory.subselectQuery( getSObjectType2() );
        return configureQueryFactory( subSelectQueryFactory, false, false, true, false );
    }

    /**
     * Adds a subselect QueryFactory based on this selector to the given QueryFactor, return the parentQueryFactory.
     */
    public fflib_QueryFactory addQueryFactorySubselect( fflib_QueryFactory parentQueryFactory, String relationshipName ){
        return addQueryFactorySubselect( parentQueryFactory, relationshipName, true );
    }

    /**
	 * Adds a subselect QueryFactory based on this selector to the given QueryFactor, but without access checks.
	 */
    public fflib_QueryFactory addQueryFactorySubselectNoAccessChecks( fflib_QueryFactory parentQueryFactory, String relationshipName, Boolean includeSelectorFields ){
        fflib_QueryFactory subSelectQueryFactory = parentQueryFactory.subselectQuery( relationshipName );
        return configureQueryFactory( subSelectQueryFactory, false, false, includeSelectorFields, false );
    }

    /**
      * Adds a subselect QueryFactory based on this selector to the given QueryFactor.
      */
    public fflib_QueryFactory addQueryFactorySubselect( fflib_QueryFactory parentQueryFactory, String relationshipName, Boolean includeSelectorFields ){
        fflib_QueryFactory subSelectQueryFactory = parentQueryFactory.subselectQuery( relationshipName );
        return configureQueryFactory( subSelectQueryFactory, m_enforceCRUD, m_enforceFLS, includeSelectorFields, m_includeRelatedFieldSetFields );
    }

    /**
     * Constructs the default SOQL query for this selector, see selectSObjectsById and queryLocatorById.
     */
    private String buildQuerySObjectById(){
        return newQueryFactory().setCondition( 'id in :idSet' ).toSOQL();
    }

    /**
     * Configures a QueryFactory instance according to the configuration of this selector.
     */
    private fflib_QueryFactory configureQueryFactory( fflib_QueryFactory queryFactory, Boolean assertCRUD, Boolean enforceFLS,
        Boolean includeSelectorFields, Boolean includeRelatedFieldSetFields ){
        // CRUD and FLS security required?
        if( assertCRUD ){
            try{
                // Leverage QueryFactory for CRUD checking 
                queryFactory.assertIsAccessible();
            } catch( fflib_SecurityUtils.CrudException e ){
                // Marshal exception into DomainException for backwards compatibility
                throw new fflib_SObjectDomain.DomainException( 'Permission to access an ' + getSObjectType().getDescribe().getName() + ' denied.' );
            }
        }
        queryFactory.setEnforceFLS( enforceFLS );

        // Configure the QueryFactory with the Selector fields?        
        if( includeSelectorFields ){
            // select the Selector fields and FieldSets and set order
            queryFactory.selectFields( getSObjectFieldList() );

            List<Schema.FieldSet> fieldSetList = getSObjectFieldSetList();
            if( m_includeFieldSetFields && fieldSetList != null ){
                for( Schema.FieldSet fieldSet : fieldSetList ){
                    queryFactory.selectFieldSet( fieldSet );
                }
            }

            // Automatically select the CurrencyIsoCode for MC orgs (unless the object is a known exception to the rule)
            if( UserInfo.isMultiCurrencyOrganization() && CURRENCY_ISO_CODE_ENABLED ){
                queryFactory.selectField( 'CurrencyIsoCode' );
            }
        }

        // Configure the QueryFactory with the related Selector fields?
        if( includeRelatedFieldSetFields ){
            queryFactory.selectFields( getRelatedFieldSet() );
        }

        // Parse the getOrderBy()
        for( String orderBy : getOrderBy().split( ',' ) ){
            List<String> orderByParts = orderBy.trim().split( ' ' );
            String fieldNamePart = orderByParts[ 0 ];
            String fieldSortOrderPart = orderByParts.size() > 1 ? orderByParts[ 1 ] : null;
            fflib_QueryFactory.SortOrder fieldSortOrder = fflib_QueryFactory.SortOrder.ASCENDING;
            if( fieldSortOrderPart == null ){
                fieldSortOrder = fflib_QueryFactory.SortOrder.ASCENDING;
            } else if( fieldSortOrderPart.equalsIgnoreCase( 'DESC' ) ){
                fieldSortOrder = fflib_QueryFactory.SortOrder.DESCENDING;
            } else if( fieldSortOrderPart.equalsIgnoreCase( 'ASC' ) ){
                fieldSortOrder = fflib_QueryFactory.SortOrder.ASCENDING;
            }
            queryFactory.addOrdering( fieldNamePart, fieldSortOrder, orderBy.containsIgnoreCase( 'NULLS LAST' ) );
        }

        queryFactory.setSortSelectFields( m_sortSelectFields );

        return queryFactory;
    }

    /**
     * Method for selecting records for deletion.
     *
     * @param 	queryConditionString	The query criteria (F.e. Origin = 'Phone')
     * @return  List of records for deletion.
     */
    public Database.QueryLocator selectDeleteBatchRecords( String queryConditionString ){
        // TODO: condition string will need to be sanitised as input.

        fflib_QueryFactory query = newQueryFactory();
        query.setCondition( String.escapeSingleQuotes( queryConditionString ).replace( '\\', '' ) );

        return Database.getQueryLocator( query.toSOQL() );
    }

    /**
     * Method for querying and retrieving all SObject records associated with the relevant SObjectType in context by:
     *   - Selecting the fields described via getSObjectFieldsList() and getSObjectFieldSetList() (if included);
     *   - From the SObject described by getSObjectType();
     *   - Ordered by the fields returned via default getOrderBy().
     *
     * @return List of SObject records
     */
    public List<SObject> selectAllSObjectRecords(){
        return Database.query( newQueryFactory().toSOQL() );
    }
}