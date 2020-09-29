module Dashboard.InstanceGroup exposing (cardView, hdCardView)

import Application.Models exposing (Session)
import Assets
import Concourse
import Concourse.BuildStatus exposing (BuildStatus(..))
import Concourse.PipelineStatus as PipelineStatus
import Dashboard.Group.Models exposing (Pipeline)
import Dashboard.Pipeline exposing (pipelineStatus)
import Dashboard.Styles as Styles
import Dict exposing (Dict)
import Duration
import HoverState
import Html exposing (Html)
import Html.Attributes
    exposing
        ( attribute
        , class
        , classList
        , draggable
        , href
        , id
        , style
        )
import Html.Events exposing (onClick, onMouseEnter, onMouseLeave)
import List.Extra
import Message.Effects as Effects
import Message.Message exposing (DomID(..), Message(..), PipelinesSection(..))
import Routes
import Set
import SideBar.SideBar as SideBar
import Time
import UserState
import Views.FavoritedIcon
import Views.Icon as Icon
import Views.InstanceGroupBadge as InstanceGroupBadge
import Views.PauseToggle as PauseToggle
import Views.Spinner as Spinner
import Views.Styles


hdCardView :
    { pipeline : Pipeline
    , pipelines : List Pipeline
    , resourceError : Bool
    , dashboardView : Routes.DashboardView
    , query : String
    }
    -> Html Message
hdCardView { pipeline, pipelines, resourceError, dashboardView, query } =
    Html.a
        ([ class "card"
         , attribute "data-pipeline-name" pipeline.name
         , attribute "data-team-name" pipeline.teamName
         , onMouseEnter <| TooltipHd pipeline.name pipeline.teamName
         , href <|
            Routes.toString <|
                Routes.Dashboard
                    { searchType = Routes.Normal query <| Just { teamName = pipeline.teamName, name = pipeline.name }
                    , dashboardView = dashboardView
                    }
         ]
            ++ Styles.instanceGroupCardHd
        )
    <|
        [ Html.div
            Styles.instanceGroupCardBodyHd
            [ InstanceGroupBadge.view <| List.length (pipeline :: pipelines)
            , Html.div
                (class "dashboardhd-group-name" :: Styles.instanceGroupCardNameHd)
                [ Html.text pipeline.name ]
            ]
        ]
            ++ (if resourceError then
                    [ Html.div Styles.resourceErrorTriangle [] ]

                else
                    []
               )


cardView :
    Session
    ->
        { pipeline : Pipeline
        , pipelines : List Pipeline
        , hovered : HoverState.HoverState
        , pipelineRunningKeyframes : String
        , resourceError : Bool
        , pipelineJobs : Dict Concourse.DatabaseID (List Concourse.JobIdentifier)
        , jobs : Dict ( Concourse.DatabaseID, String ) Concourse.Job
        , section : PipelinesSection
        , dashboardView : Routes.DashboardView
        , query : String
        }
    -> Html Message
cardView session { pipeline, pipelines, hovered, pipelineRunningKeyframes, resourceError, pipelineJobs, jobs, section, dashboardView, query } =
    Html.div
        (Styles.instanceGroupCard
            -- TODO
            ++ (if section == AllPipelinesSection && not pipeline.stale then
                    [ style "cursor" "move" ]

                else
                    []
               )
            ++ (if pipeline.stale then
                    [ style "opacity" "0.45" ]

                else
                    []
               )
        )
        [ Html.div (class "banner" :: Styles.instanceGroupCardBanner) []
        , headerView dashboardView query pipeline pipelines resourceError
        , bodyView pipelineRunningKeyframes section hovered (pipeline :: pipelines) pipelineJobs jobs
        ]


headerView : Routes.DashboardView -> String -> Pipeline -> List Pipeline -> Bool -> Html Message
headerView dashboardView query pipeline pipelines resourceError =
    Html.a
        [ href <|
            Routes.toString <|
                Routes.Dashboard
                    { searchType = Routes.Normal query <| Just { teamName = pipeline.teamName, name = pipeline.name }
                    , dashboardView = dashboardView
                    }
        , draggable "false"
        ]
        [ Html.div
            ([ class "card-header"
             , onMouseEnter <| Tooltip pipeline.name pipeline.teamName
             ]
                ++ Styles.instanceGroupCardHeader
            )
            [ InstanceGroupBadge.view <| List.length (pipeline :: pipelines)
            , Html.div
                (class "dashboard-group-name" :: Styles.instanceGroupName)
                [ Html.text pipeline.name
                ]
            , Html.div
                [ classList [ ( "dashboard-resource-error", resourceError ) ] ]
                []
            ]
        ]


bodyView :
    String
    -> PipelinesSection
    -> HoverState.HoverState
    -> List Pipeline
    -> Dict Concourse.DatabaseID (List Concourse.JobIdentifier)
    -> Dict ( Concourse.DatabaseID, String ) Concourse.Job
    -> Html Message
bodyView pipelineRunningKeyframes section hovered pipelines pipelineJobs jobs =
    let
        cols =
            floor <| sqrt <| toFloat <| List.length pipelines

        padRow row =
            let
                padding =
                    List.range 1 (cols - List.length row)
                        |> List.map (always Nothing)
            in
            List.map Just row ++ padding

        pipelineBox p =
            let
                pipelinePage =
                    Routes.toString <|
                        Routes.pipelineRoute p

                curPipelineJobs =
                    Dict.get p.id pipelineJobs
                        |> Maybe.withDefault []
                        |> List.filterMap
                            (\{ pipelineId, jobName } ->
                                Dict.get
                                    ( pipelineId, jobName )
                                    jobs
                            )
            in
            Html.div
                (Styles.instanceGroupCardPipelineBox
                    pipelineRunningKeyframes
                    (HoverState.isHovered
                        (PipelinePreview section p.id)
                        hovered
                    )
                    (pipelineStatus curPipelineJobs p)
                    ++ [ onMouseEnter <| Hover <| Just <| PipelinePreview section p.id
                       , onMouseLeave <| Hover Nothing
                       ]
                )
                [ Html.a
                    [ href pipelinePage
                    , style "flex-grow" "1"
                    ]
                    []
                ]

        emptyBox =
            Html.div [ style "margin" "2px", style "flex-grow" "1" ] []

        viewRow row =
            List.map
                (\mp ->
                    case mp of
                        Nothing ->
                            emptyBox

                        Just p ->
                            pipelineBox p
                )
                row
    in
    Html.div
        (class "card-body" :: Styles.instanceGroupCardBody)
        (List.Extra.greedyGroupsOf cols pipelines
            |> List.map padRow
            |> List.map
                (\paddedRow ->
                    Html.div
                        [ style "display" "flex"
                        , style "flex-grow" "1"
                        ]
                        (viewRow paddedRow)
                )
        )
